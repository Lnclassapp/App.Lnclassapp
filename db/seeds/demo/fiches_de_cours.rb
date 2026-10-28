# Les fiches de cours en blocs de db/seeds/data/course_sheets (chantier contenu-en-blocs, #318) : la fiche Thalès, pour que
# la leçon « Propriétés de Thalès dans un triangle » (3ème) ait sa fiche dans un environnement de PR et en développement.
# Importées par la vraie chaîne (StartImport → RunImport → Catalog::ImportCourseSheetJob) avec le compte équipe fictif
# 0700000000, comme lecons_completes.rb, après lequel il est joué : la leçon n'existe que si lecons_completes l'a semée
# (il est réservé aux environnements de PR). Une leçon absente est dite et laissée en développement, et lève dans un environnement de PR ; rejoué, il n'importe que les fiches absentes.
unless Rails.env.development? || PrEnvironment.active?
  raise "db/seeds/demo/fiches_de_cours.rb est réservé au développement et aux environnements de PR"
end

log = ->(message) { puts "[fiches-de-cours] #{message}" }
team = Orm::User.find_by(contact: "0700000000")
sheets = Rails.root.glob("db/seeds/data/course_sheets/*.json").sort

if team.nil?
  log.call("compte équipe 0700000000 absent (seed development), aucune fiche importée")
else
  actor = Repositories::Identity::UserRepository.new.actor_for(user_id: team.id)
  noop_queue = Object.new.tap { |queue| queue.define_singleton_method(:enqueue) { |**| nil } }
  transaction = Repositories::Shared::Transaction.new
  imported = 0

  sheets.each do |path|
    document = JSON.parse(path.read)
    course = Orm::Course.find_by(slug: document["course"])
    if course.nil?
      message = "leçon « #{document['course']} » absente : fiche #{path.basename} non importée (elle est semée par demo/lecons_completes, réservé aux environnements de PR)"
      raise message if PrEnvironment.active?

      log.call(message)
      next
    end
    next if Orm::CourseSheet.exists?(course_id: course.id)

    started = UseCases::Catalog::StartImport.new(
      reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
      queue: noop_queue, transaction:, clock: Time.zone
    ).call(actor:, dto: Dtos::Catalog::ImportUploadInput.new(
      kind: "course_sheet",
      files: [ Dtos::Catalog::ImportUploadInput::Upload.new(io: StringIO.new(JSON.generate(document)), filename: path.basename.to_s) ]
    ))
    raise "import de #{path.basename} refusé : #{started.errors}" if started.failure?

    UseCases::Catalog::RunImport.new(
      adapter: Catalog::ImportCourseSheetJob.new.send(:adapter), schema: Repositories::Catalog::ImportSchemaValidator.new,
      reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
      users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
      transaction:, clock: Time.zone
    ).call(report_id: started.value.id)
    report = Orm::ImportReport.find(started.value.id)
    raise "import de #{path.basename} en échec : #{report.attributes.slice('status', 'imported_count', 'error_count')}" unless report.status == "completed"

    imported += 1
  end
  log.call("#{imported} fiche(s) de cours importée(s) sur #{sheets.size}")
end
