# Les leçons complètes de docs/contenus/lecons-traitees (3 par matière, de la 6ème à la Tle : cours, fiches, exercices),
# pour les données de test (chantier environnements-de-pr) : semées dans un environnement de PR après les comptes fictifs,
# et par bin/tester-pr <PR> --demo. Importées par la vraie chaîne (Imports → Cours complets), 50 fichiers par envoi
# (ADR-0068), puis publiées en cascade par le compte équipe fictif 0700000000. Rejoué, il n'importe que les leçons
# absentes et ne publie que ce qui ne l'est pas. Joué après trois_etablissements.rb, qui crée la matière EDHC.
unless Rails.env.development? || PrEnvironment.active?
  raise "db/seeds/demo/lecons_completes.rb est réservé au développement et aux environnements de PR"
end

LESSON_PATHS = Rails.root.glob("docs/contenus/lecons-traitees/*/*/*.json").sort.freeze
BATCH = 50

log = ->(message) { puts "[lecons-completes] #{message}" }
team = Orm::User.find_by!(contact: "0700000000")
actor = Repositories::Identity::UserRepository.new.actor_for(user_id: team.id)

# Une leçon est là si son cours existe déjà pour le même niveau, la même série et la même matière.
course_for = lambda do |course|
  Orm::Course.joins(:level, :material).left_joins(:series)
             .find_by(name: course["name"], levels: { name: course["level_name"] }, materials: { name: course["material_name"] },
                      series: { name: course["series_name"] })
end
# Les leçons de 1ère A visent la série « A », que le référentiel n'ouvre pas en 1ère (seulement A1, A2, C, D) : pour
# les données de test, elles sont importées en 1ère A1 et en 1ère A2 (choix du 2026-10-23, le contenu reste à corriger).
SERIES_FOR_TEST = { [ "1ère", "A" ] => %w[A1 A2] }.freeze
lessons = LESSON_PATHS.flat_map do |path|
  document = JSON.parse(path.read)
  course = document["courses"].first
  SERIES_FOR_TEST.fetch([ course["level_name"], course["series_name"] ], [ course["series_name"] ]).map do |series_name|
    variant = document.deep_dup.tap { it["courses"].first["series_name"] = series_name }
    [ path, variant, variant["courses"].first ]
  end
end
missing = lessons.reject { |_path, _document, course| course_for.(course) }

if missing.any?
  noop_queue = Object.new.tap { |queue| queue.define_singleton_method(:enqueue) { |**| nil } }
  transaction = Repositories::Shared::Transaction.new
  missing.each_slice(BATCH) do |batch|
    uploads = batch.map do |path, document, course|
      Dtos::Catalog::ImportUploadInput::Upload.new(io: StringIO.new(JSON.generate(document)),
                                                   filename: "#{path.parent.basename}-#{course['series_name']}-#{path.basename}")
    end
    started = UseCases::Catalog::StartImport.new(
      reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
      queue: noop_queue, transaction:, clock: Time.zone
    ).call(actor:, dto: Dtos::Catalog::ImportUploadInput.new(kind: "course_tree", files: uploads))
    raise "import refusé : #{started.errors}" if started.failure?

    UseCases::Catalog::RunImport.new(
      adapter: Catalog::ImportCourseTreeJob.new.send(:adapter), schema: Repositories::Catalog::ImportSchemaValidator.new,
      reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
      users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
      transaction:, clock: Time.zone
    ).call(report_id: started.value.id)
    report = Orm::ImportReport.find(started.value.id)
    raise "import en échec : #{report.attributes.slice('status', 'imported_count', 'error_count')}" unless report.status == "completed"
  end
end

# Une leçon que la chaîne d'import refuse (série absente du référentiel pour ce niveau, matière inconnue) reste dans le
# rapport d'import de l'équipe et n'arrête pas le semis : elle est seulement comptée.
refused = lessons.reject { |_path, _document, course| course_for.(course) }
                .map { |path, _document, _course| path.relative_path_from(Rails.root.join("docs/contenus/lecons-traitees")).to_s }
courses = lessons.filter_map { |_path, _document, course| course_for.(course) }
dependencies = { audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
                 policy: Policies::Catalog::ManageContentPolicy.new, clock: Time.zone }
cascade = UseCases::Catalog::PublishCascade.new(
  courses: Repositories::Catalog::CourseRepository.new, essentials: Repositories::Catalog::EssentialRepository.new,
  exercises: Repositories::Assessment::ExerciseRepository.new, transaction: dependencies[:transaction], policy: dependencies[:policy],
  publish_course: UseCases::Catalog::PublishCourse.new(courses: Repositories::Catalog::CourseRepository.new, **dependencies),
  publish_essential: UseCases::Catalog::PublishEssential.new(essentials: Repositories::Catalog::EssentialRepository.new, **dependencies),
  publish_exercise: UseCases::Assessment::PublishExercise.new(exercises: Repositories::Assessment::ExerciseRepository.new, **dependencies)
)
published = courses.count do |course|
  next false if course.status == "published" &&
                Orm::Exercise.joins(:essential).where(essentials: { course_id: course.id }).where.not(status: "published").none?

  result = cascade.call(actor:, root: :course, slug: course.slug)
  raise "publication refusée pour #{course.name} : #{result.errors}" if result.failure?

  true
end
log.call("#{courses.size} leçons complètes sur #{lessons.size}, #{published} publiées maintenant")
log.call("#{refused.size} refusées par l'import (voir Imports) : #{refused.first(3).join(', ')}#{refused.size > 3 ? '…' : ''}") if refused.any?
