# Aperçu local d'un fichier de leçon (chantier standard-de-test, Lot E) : `bin/rails "contenus:apercu[docs/contenus/lecons-traitees/…json]"`,
# ou bin/apercu-lecon. Développement seulement, un fichier de docs/contenus/lecons-traitees seulement : contrôle par valider.rb, import de
# ce seul fichier par la vraie chaîne (la leçon de même titre est remplacée entière, replace: :lesson), publication en cascade, adresse.
# Un fichier refusé laisse la base intacte (l'import est transactionnel). Menace : docs/chantiers/standard-de-test/journal.md.
namespace :contenus do
  desc "Aperçu local : contrôle, importe seul ce fichier de leçon (development), le publie et affiche son adresse"
  task :apercu, [ :fichier ] => :environment do |_task, args|
    root = Rails.root.join("docs/contenus/lecons-traitees")
    stop = ->(message) { abort("[apercu] #{message}") }
    stop.call("refusé : l'aperçu ne tourne qu'en development (environnement actuel : #{Rails.env}). Rien n'est importé.") unless Rails.env.development?

    # Le chemin, liens symboliques suivis, reste sous docs/contenus/lecons-traitees et se termine par .json.
    given = args[:fichier].to_s.strip
    real = (File.realpath(Rails.root.join(given)) if given.present? && File.file?(Rails.root.join(given)))
    inside = real && File.extname(real) == ".json" && real.start_with?("#{File.realpath(root)}/")
    stop.call("refusé : un fichier .json de docs/contenus/lecons-traitees est attendu (reçu : #{given.inspect}). Rien n'est importé.") unless inside

    require Rails.root.join("script/contenus/valider")
    stop.call("arrêté : le fichier est refusé par valider.rb, rien n'est importé.") unless Contenus::Valider.run([ real ]).zero?

    document = JSON.parse(File.read(real, encoding: "UTF-8"))
    lesson = document["courses"].first
    transaction = Repositories::Shared::Transaction.new
    reports = Repositories::Catalog::ImportReportRepository.new
    files = Repositories::Catalog::ImportFileStore.new
    courses = Repositories::Catalog::CourseRepository.new
    essentials = Repositories::Catalog::EssentialRepository.new
    exercises = Repositories::Assessment::ExerciseRepository.new
    actor = Repositories::Identity::UserRepository.new.oldest_active_team_actor
    stop.call("arrêté : aucun membre d'équipe actif (lancer bin/rails db:seed). Rien n'est importé.") if actor.nil?

    Repositories::Catalog::ReferentialCompleter.new.complete
    no_queue = Object.new.tap { |queue| queue.define_singleton_method(:enqueue) { |**| nil } }
    started = UseCases::Catalog::StartImport.new(reports:, files:, queue: no_queue, transaction:, clock: Time.zone).call(
      actor:, dto: Dtos::Catalog::ImportUploadInput.new(
        kind: "course_tree", files: [ Dtos::Catalog::ImportUploadInput::Upload.new(io: StringIO.new(JSON.generate(document)), filename: "apercu-#{File.basename(real)}") ]
      )
    )
    stop.call("arrêté : import non démarré (#{started.errors}). Rien n'est importé.") if started.failure?

    adapter = UseCases::Catalog::ImportCourseTree.new(courses:, essentials:, taxonomy: Repositories::Catalog::TaxonomyRepository.new,
                                                      writer: Repositories::Catalog::ContentTreeWriter.new, replace: :lesson)
    ran = UseCases::Catalog::RunImport.new(adapter:, schema: Repositories::Catalog::ImportSchemaValidator.new, reports:, files:,
                                           users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
                                           transaction:, clock: Time.zone).call(report_id: started.value.id)
    report = ran.success? ? ran.value : nil
    unless report && report.status == "completed" && report.error_count.zero?
      reasons = Array(report&.import_errors).first(5).map { |error| [ error.code, error.path ].join(" ") }
      stop.call("import refusé (#{report&.status || ran.code}) : #{reasons.join(' ; ')}. La base est intacte.")
    end

    course = Orm::Course.joins(:level, :material).left_joins(:series)
                        .find_by!(name: lesson["name"], levels: { name: lesson["level_name"] }, materials: { name: lesson["material_name"] },
                                  series: { name: lesson["series_name"] })
    dependencies = { audit_log: Repositories::Identity::AuditLogRepository.new, transaction:, policy: Policies::Catalog::ManageContentPolicy.new, clock: Time.zone }
    published = UseCases::Catalog::PublishCascade.new(
      courses:, essentials:, exercises:, transaction:, policy: dependencies[:policy],
      publish_course: UseCases::Catalog::PublishCourse.new(courses:, **dependencies),
      publish_essential: UseCases::Catalog::PublishEssential.new(essentials:, **dependencies),
      publish_exercise: UseCases::Assessment::PublishExercise.new(exercises:, **dependencies)
    ).call(actor:, root: :course, slug: course.slug)
    stop.call("publication refusée (#{published.code}) : la leçon est importée en brouillon.") if published.failure?

    # Un compte élève fictif (plage 0[157]0000xxxx) d'une classe du niveau et de la série de la leçon, si le jeu standard est chargé.
    classrooms = Orm::Classroom.where(level_id: course.level_id, series_id: course.series_id, status: "active")
    student = Orm::User.where(role: "student").where("contact ~ ?", Entities::School::FictitiousIdentity::RANGE.source.delete_prefix("\\A").delete_suffix("\\z"))
                       .joins("INNER JOIN classroom_students ON classroom_students.student_id = users.id AND classroom_students.left_at IS NULL")
                       .where(classroom_students: { classroom_id: classrooms.select(:id) }).order(:id).first

    puts "[apercu] #{lesson['name']} : publiée (#{published.value.exercises} exercice(s)), seule cette leçon a été importée."
    puts "[apercu] Adresse : http://localhost:3000/courses/#{course.slug}"
    if student
      puts "[apercu] Compte élève de la série : #{student.contact}, PIN 2468 (compte fictif)"
    else
      puts "[apercu] Aucun compte élève fictif de ce niveau : bin/jeu-standard charge le jeu standard."
    end
  end
end
