# Banc de l'import des cours complets (chantier import-cours-multiple, ADR-0068 §1 et §7, PRD §7, IM-14).
#
#   bin/rails runner script/bench/import_course_tree.rb            # 200 puis 500 cours
#   bin/rails runner script/bench/import_course_tree.rb 40 200     # tailles au choix
#   BENCH_RUNS=5 bin/rails runner script/bench/import_course_tree.rb 500
#
# Sur la base de développement, qui porte le référentiel de db/seeds (Tle, série D, Mathématiques, Physique-Chimie,
# SVT) et au moins un membre de l'équipe. Pour chaque taille N, le banc fabrique N cours en clonant les 4 leçons de
# docs/contenus/lecons-traitees/tle-d/ (noms suffixés « — banc i »), rangés par fichiers de FILE_COURSES cours au plus
# (≈ 11 Mo, sous la limite de 20 Mo par fichier). Il les importe par la vraie chaîne : UseCases::Catalog::StartImport,
# puis Catalog::ImportCourseTreeJob.perform_now. Si l'envoi accepte plusieurs fichiers, c'est un seul import ; sinon,
# un import par fichier, l'un après l'autre, et les durées s'additionnent. Il fait BENCH_RUNS passages (3 par défaut)
# et affiche la médiane de chaque phase :
#
#   schéma      ImportSchemaValidator#validate (json_schemer)
#   métier      ImportCourseTree#validate_root (ContentNode, taxonomie, slugs)
#   écriture    ImportCourseTree#write, donc ContentTreeWriter#write, dans la transaction du lot
#     dont HTML   RichTextSanitizer.call, compté dans l'écriture
#   reste       lecture du fichier, analyse JSON, rapport, transactions
#   traitement  le job, du lancement au rapport « Terminé » (la mesure de l'IM-14)
#
# Après chaque passage, tout ce qu'il a créé est supprimé (lignes d'id supérieur au maximum d'avant, enfants d'abord),
# y compris les rapports d'import, leurs fichiers et leurs événements d'audit. Hors CI : la mesure dépend de la machine.

module ImportCourseTreeBench
  LESSONS = Rails.root.glob("docs/contenus/lecons-traitees/tle-d/*.json").sort
  SIZES = ARGV.any? ? ARGV.map { Integer(it) } : [ 200, 500 ]
  RUNS = Integer(ENV.fetch("BENCH_RUNS", 3))
  FILE_COURSES = 200
  PHASES = { schema: "schéma", business: "métier", write: "écriture", sanitize: "  dont HTML", rest: "reste",
             job: "traitement", start: "StartImport" }.freeze
  # Enfants d'abord : les clés étrangères refusent qu'un parent parte avant eux.
  CONTENT = %w[answers questions exercises action_text_rich_texts essentials courses].freeze
  TIMES = Hash.new(0.0)
  Upload = Data.define(:io, :filename)

  # Les queues de l'application ne sont pas sollicitées : le job est lancé ici, dans ce processus.
  class Queue
    attr_reader :report_id

    def enqueue(kind:, report_id:) = (@report_id = report_id)
  end

  module_function

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def timed(phase)
    started = clock
    yield
  ensure
    TIMES[phase] += clock - started
  end

  def instrument
    Repositories::Catalog::ImportSchemaValidator.prepend(Module.new { def validate(...) = ImportCourseTreeBench.timed(:schema) { super } })
    UseCases::Catalog::ImportCourseTree.prepend(Module.new do
      def validate_root(...) = ImportCourseTreeBench.timed(:business) { super }
      def write(...) = ImportCourseTreeBench.timed(:write) { super }
    end)
    Repositories::Shared::RichTextSanitizer.singleton_class.prepend(Module.new { def call(...) = ImportCourseTreeBench.timed(:sanitize) { super } })
  end

  # → [Upload], un fichier lnclass.course-tree par tranche de FILE_COURSES cours.
  def files(size)
    roots = LESSONS.flat_map { |file| JSON.parse(file.read).fetch("courses") }
    courses = Array.new(size) { |index| roots[index % roots.size].merge("name" => "#{roots[index % roots.size]['name']} — banc #{index + 1}") }
    courses.each_slice(FILE_COURSES).with_index(1).map do |slice, rank|
      Upload.new(io: StringIO.new(JSON.generate("format" => "lnclass.course-tree", "version" => 1, "courses" => slice)),
                 filename: "banc-#{size}-cours-#{rank}.json")
    end
  end

  def multiple_files? = Dtos::Catalog::ImportUploadInput.method_defined?(:files=)

  # Un envoi dans la forme d'ImportUploadInput : une liste d'ImportUploadInput::Upload, ou un fichier seul.
  def dto(uploads)
    uploads.each { it.io.rewind }
    unless multiple_files?
      return Dtos::Catalog::ImportUploadInput.new(kind: "course_tree", io: uploads.sole.io, filename: uploads.sole.filename)
    end

    Dtos::Catalog::ImportUploadInput.new(kind: "course_tree",
                                         files: uploads.map { Dtos::Catalog::ImportUploadInput::Upload.new(io: it.io, filename: it.filename) })
  end

  def actor
    member = Orm::User.where(role: "team").order(:id).first || abort("Aucun membre de l'équipe : lancez bin/rails db:seed.")
    Entities::Identity::Actor.new(user_id: member.id, role: :team, team_role: member.team_role)
  end

  def import(uploads)
    queue = Queue.new
    timed(:start) do
      started = UseCases::Catalog::StartImport.new(
        reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new, queue:,
        transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      ).call(actor:, dto: dto(uploads))
      abort("StartImport refusé : #{started.inspect}") if started.failure?
    end
    timed(:job) { Catalog::ImportCourseTreeJob.perform_now(queue.report_id) }
    Orm::ImportReport.find(queue.report_id)
  end

  def maxima = (CONTENT + %w[import_reports audit_events]).index_with { |table| max_id(table) }

  # Les tables sont une liste fixe, jamais une saisie : Arel les cite, sans interpolation dans le SQL.
  def arel_table(table) = Arel::Table.new(table)

  def max_id(table) = ActiveRecord::Base.connection.select_value(arel_table(table).project(arel_table(table)[:id].maximum)).to_i

  def run(size, uploads)
    TIMES.clear
    GC.start
    before = maxima
    reports = multiple_files? ? [ import(uploads) ] : uploads.map { import([ it ]) }
    imported = reports.sum(&:imported_count)
    warn "  ⚠️  #{reports.map(&:status).uniq.join(', ')}, #{imported}/#{size} importés" unless reports.all? { it.status == "completed" } && imported == size
    TIMES.merge(rest: TIMES[:job] - TIMES[:schema] - TIMES[:business] - TIMES[:write])
  ensure
    clean(before) if before
  end

  def clean(before)
    connection = ActiveRecord::Base.connection
    reports = Orm::ImportReport.where("id > ?", before.fetch("import_reports"))
    ActiveStorage::Attachment.where(record_type: Orm::ImportReport.name, record_id: reports.select(:id)).find_each(&:purge)
    (CONTENT + %w[audit_events]).each do |table|
      delete = Arel::DeleteManager.new.from(arel_table(table)).where(arel_table(table)[:id].gt(before.fetch(table)))
      connection.delete(delete)
    end
    reports.delete_all
  end

  def median(values) = values.sort[values.size / 2]

  def call
    instrument
    SIZES.each do |size|
      uploads = files(size)
      runs = Array.new(RUNS) { |index| run(size, uploads).tap { |times| puts format("  passage %d : %.2f s", index + 1, times[:job]) } }
      mode = multiple_files? || uploads.one? ? "un import" : "#{uploads.size} imports d'un fichier, à la suite"
      puts "#{size} cours, #{uploads.size} fichier(s), #{uploads.sum { it.io.size } / 1024} Ko, #{mode} — médiane de #{RUNS} passages"
      PHASES.each { |phase, label| puts format("  %-12s %6.2f s", label, median(runs.map { it[phase] })) }
    end
  end
end

ImportCourseTreeBench.call
