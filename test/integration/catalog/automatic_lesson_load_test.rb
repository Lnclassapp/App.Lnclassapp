require "test_helper"
require "rake"

# ADR chargement-automatique-des-lecons-hors-production : `bin/rails contenus:charger` sur une vraie base, avec le vrai fichier Thalès
# (4 sujets de devoir, deux exercices par notion). Les huit scénarios du PRD §4, puis la sûreté du démarrage (verrou, exception, pas d'équipe).
class Catalog::AutomaticLessonLoadTest < ActiveSupport::TestCase
  FILE = Rails.root.join("docs/contenus/lecons-traitees/3eme/mathematiques/proprietes-de-thales-dans-un-triangle.json")
  IMPORT_NAME = "chargement-automatique-3eme-mathematiques-proprietes-de-thales-dans-un-triangle.json"
  LOCK = "SELECT %s(hashtext('contenus:charger'))"

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("contenus:charger")
    @document = JSON.parse(FILE.read)
    @lesson = @document["courses"].first
    @oldest = create_team_member(team_role: "content", second_factor: false)
    @oldest.update_columns(created_at: 10.days.ago)
    create_team_member(team_role: "admin", second_factor: false)
    create_team_member(team_role: "field", second_factor: false).update_columns(created_at: 20.days.ago, anonymized_at: 15.days.ago)
  end

  def with_env(**variables)
    saved = variables.keys.to_h { [ it, ENV[it.to_s] ] }
    variables.each { |key, value| ENV[key.to_s] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key.to_s] = value }
  end

  def charger(environment = "Develop", **env)
    task = Rake::Task["contenus:charger"]
    task.reenable
    output = nil
    with_env(RAILWAY_ENVIRONMENT_NAME: environment, PR_BASE_ENVIRONMENT: nil, **env) { output, = capture_io { task.invoke } }
    output
  end

  # Le fichier d'avant : moins de sujets, un seul exercice par notion, importé par la chaîne ordinaire puis publié.
  def import_old_version(document = @document)
    old = document.deep_dup
    course = old["courses"].first
    course["subjects"] = course["subjects"].first(1)
    course["notions"].each { |notion| notion["exercise"] = Array.wrap(notion["exercise"]).first }
    report = create_import_report(kind: "course_tree", imported_by: @oldest)
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(io: StringIO.new(old.to_json), filename: "lecon.json") ])
    UseCases::Catalog::RunImport.new(
      adapter: Catalog::ImportCourseTreeJob.new.send(:adapter), reports: Repositories::Catalog::ImportReportRepository.new,
      files: Repositories::Catalog::ImportFileStore.new, schema: Repositories::Catalog::ImportSchemaValidator.new,
      users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
      transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    ).call(report_id: report.id)
    assert_equal "completed", report.reload.status
    assert_empty report.import_errors
    Orm::Course.find_by!(name: @lesson["name"]).tap do |course_row|
      now = Time.current
      Orm::Course.where(id: course_row.id).update_all(status: "published", published_at: now)
      Orm::Essential.where(course_id: course_row.id).update_all(status: "published", published_at: now)
      Orm::Exercise.where(course_id: course_row.id).update_all(status: "published", published_at: now)
      # Le texte des fiches "d'avant" : il doit survivre au chargement.
      Orm::Essential.where(course_id: course_row.id).find_each { |notion| notion.update_columns(sheet: notion.sheet.merge("remember" => "Texte d'avant #{notion.position}")) }
    end
  end

  def automatic_reports = Orm::ImportReport.where(kind: "course_tree").where("files @> ?::jsonb", [ { name: IMPORT_NAME } ].to_json)

  def subject_exercise_count = @lesson["subjects"].sum { it["exercises"].size }

  # CA : une leçon publiée est remplacée sur Develop
  test "Develop replaces the exercises and subjects of the published Thalès lesson, keeps its sheets, erases the student's session, and leaves a finished line" do
    seed_referential
    course = import_old_version
    notion = course.essentials.order(:position).first
    student = create_student
    session = create_exercise_session(student:, exercise: notion.exercises.first, status: "completed")
    create_attempt(session:, question: session.exercise.questions.first)
    sheets = course.essentials.order(:position).pluck(:slug, :name, :sheet)
    assert_equal 1, course.subjects.count

    output = charger("Develop")

    assert_includes output, "#{IMPORT_NAME} : loaded"
    course.reload
    assert_equal @lesson["subjects"].map { it["title"] }, course.subjects.order(:position).pluck(:title)
    assert_equal [ 2, 2, 2 ], course.essentials.order(:position).map { it.exercises.count }
    exercises = Orm::Exercise.where(course_id: course.id)
    assert_equal 3 * 2 + 4 + subject_exercise_count, exercises.count
    assert_equal [ "published" ], exercises.distinct.pluck(:status)
    assert_equal [ "published" ], [ course.status ]
    assert_equal sheets, course.essentials.order(:position).pluck(:slug, :name, :sheet)
    assert_equal [ 0, 0 ], [ Orm::ExerciseSession.count, Orm::QuestionAttempt.count ]
    assert_equal @lesson["figures"].map { it["key"] }.sort, course.figures.map { it["key"] }.sort
    line = automatic_reports.sole
    assert_equal [ "completed", @oldest.id, 1, 0, Digest::SHA256.hexdigest(FILE.read) ], line.values_at(:status, :imported_by_id, :imported_count, :error_count, :checksum_sha256)
    assert_equal [ IMPORT_NAME ], line.files.map { it["name"] }
  end

  test "Develop creates the lesson whole when it is absent, then publishes it" do
    seed_referential

    charger("Develop")

    course = Orm::Course.find_by!(name: @lesson["name"])
    assert_equal [ "published" ], [ course.status ]
    assert_equal [ "published" ], course.essentials.distinct.pluck(:status)
    assert_equal [ "published" ], Orm::Exercise.where(course_id: course.id).distinct.pluck(:status)
    assert_equal 4, course.subjects.count
  end

  # CA : seules les leçons à sujets de devoir sont chargées
  test "Staging loads only the lessons with subjects: no other lesson of the repository is created" do
    seed_referential

    charger("staging")

    assert_equal [ @lesson["name"] ], Orm::Course.pluck(:name)
  end

  # CA : un fichier inchangé n'est pas rechargé
  test "an unchanged file is not loaded again: no new line" do
    seed_referential
    first = charger("Develop")

    second = charger("Develop")

    assert_includes first, "loaded"
    assert_includes second, "#{IMPORT_NAME} : unchanged"
    assert_equal 1, automatic_reports.count
  end

  test "an unchanged file whose publication was interrupted is published again, without a new import line" do
    seed_referential
    charger("Develop")
    course = Orm::Course.find_by!(name: @lesson["name"])
    Orm::Exercise.where(course_id: course.id).first.update_columns(status: "draft", published_at: nil)

    output = charger("Develop")

    assert_includes output, "#{IMPORT_NAME} : republished"
    assert_equal [ "published" ], Orm::Exercise.where(course_id: course.id).distinct.pluck(:status)
    assert_equal 1, automatic_reports.count
  end

  test "a changed file is loaded again" do
    seed_referential
    charger("Develop")
    automatic_reports.update_all(checksum_sha256: "0" * 64)

    charger("Develop")

    assert_equal 2, automatic_reports.count
  end

  # CA : la production n'est jamais touchée
  test "production, whatever the case, never touches a lesson or a line" do
    seed_referential
    course = import_old_version
    before = [ Orm::Exercise.where(course_id: course.id).pluck(:id).sort, Orm::ImportReport.count ]

    %w[production Production PRODUCTION].each { |name| assert_includes charger(name), "rien n'est chargé" }

    assert_equal before, [ Orm::Exercise.where(course_id: course.id).pluck(:id).sort, Orm::ImportReport.count ]
  end

  test "a PR environment and a machine without environment name load nothing" do
    seed_referential

    charger("pr-12", PR_BASE_ENVIRONMENT: "Develop")
    charger(nil)

    assert_equal [ 0, 0 ], [ Orm::Course.count, Orm::ImportReport.count ]
  end

  # CA : un nom inconnu prévient sans charger
  test "an unknown name loads nothing and leaves one refused line 'environnement non reconnu : Recette'" do
    seed_referential

    output = charger("Recette")

    assert_includes output, "environnement non reconnu (Recette)"
    assert_equal 0, Orm::Course.count
    line = Orm::ImportReport.where(kind: "course_tree").sole
    assert_equal [ "rejected", @oldest.id, [ [ "$", "unknown_environment", { "name" => "Recette" } ] ] ],
                 [ line.status, line.imported_by_id, line.import_errors.map { [ it["path"], it["code"], it["params"] ] } ]
    assert_equal "environnement non reconnu : Recette",
                 I18n.t("teams.imports.error_codes.unknown_environment", name: "Recette", locale: :fr)
  end

  # CA : un référentiel absent refuse la leçon sans bloquer
  test "Staging without the 3ème level refuses the lesson in its line, without exception, and tries again next time" do
    create_material(name: "Mathématiques")

    output = charger("Staging")

    assert_not_includes output, "interrompu"
    assert_equal 0, Orm::Course.count
    line = automatic_reports.sole
    assert_equal [ "completed", 0, 1, [ "unknown_level" ] ], [ line.status, line.imported_count, line.error_count, line.import_errors.map { it["code"] } ]
    assert_includes output, "#{IMPORT_NAME} : refused"

    Orm::Material.delete_all
    seed_referential
    assert_includes charger("Staging"), "loaded"
    assert_equal 2, automatic_reports.count
  end

  # CA : une notion introuvable refuse la leçon
  test "a notion renamed in the environment refuses the lesson naming the notion, and no exercise or subject changes" do
    seed_referential
    course = import_old_version
    renamed = course.essentials.order(:position).second
    renamed.update_columns(name: "Autre nom")
    before = [ Orm::Exercise.where(course_id: course.id).pluck(:id).sort, course.subjects.pluck(:id).sort ]

    charger("Develop")

    line = automatic_reports.sole
    assert_equal [ 1, 0 ], [ line.error_count, line.imported_count ]
    error = line.import_errors.sole
    assert_equal "notion_not_found", error["code"]
    assert_equal @lesson["notions"].second["name"].squish, error["params"]["name"]
    assert_equal before, [ Orm::Exercise.where(course_id: course.id).pluck(:id).sort, course.subjects.pluck(:id).sort ]
    assert_equal "notion introuvable dans la fiche de cours : #{error['params']['name']}",
                 I18n.t("teams.imports.error_codes.notion_not_found", name: error["params"]["name"], locale: :fr)
  end

  # CA : l'import à la main refuse toujours une leçon publiée
  test "by hand, through the ordinary chain, the published Thalès lesson is still refused" do
    seed_referential
    course = import_old_version
    before = Orm::Exercise.where(course_id: course.id).pluck(:id).sort
    report = create_import_report(kind: "course_tree", imported_by: @oldest)
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(io: StringIO.new(FILE.read), filename: "thales.json") ])

    UseCases::Catalog::RunImport.new(
      adapter: Catalog::ImportCourseTreeJob.new.send(:adapter), reports: Repositories::Catalog::ImportReportRepository.new,
      files: Repositories::Catalog::ImportFileStore.new, schema: Repositories::Catalog::ImportSchemaValidator.new,
      users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
      transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    ).call(report_id: report.id)

    assert_equal [ "lesson_already_published" ], report.reload.import_errors.map { it["code"] }
    assert_equal before, Orm::Exercise.where(course_id: course.id).pluck(:id).sort
  end

  # Sûreté du démarrage
  test "without any active team member nothing is loaded and the task says so" do
    Orm::User.where(role: "team").update_all(anonymized_at: Time.current)
    seed_referential

    output = charger("Develop")

    assert_includes output, "aucun membre d'équipe actif"
    assert_equal [ 0, 0 ], [ Orm::Course.count, Orm::ImportReport.count ]
  end

  test "while another start-up holds the lock, nothing is loaded and the task says so; the lock is free again afterwards" do
    seed_referential
    # Un autre démarrage = une autre session PostgreSQL (les tests partagent la connexion d'ActiveRecord, une session à part est nécessaire).
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    other = PG.connect(dbname: config[:database], host: config[:host], port: config[:port], user: config[:username], password: config[:password])
    other.exec(format(LOCK, "pg_advisory_lock"))

    output = charger("Develop")

    assert_includes output, "un autre démarrage charge déjà"
    assert_equal 0, Orm::Course.count
    other.exec(format(LOCK, "pg_advisory_unlock"))
    assert_includes charger("Develop"), "loaded"
  ensure
    other&.close
  end

  test "any exception is logged and printed, the task does not fail, and the lock is released" do
    seed_referential
    logged = []

    output = stub_any_instance(UseCases::Catalog::LoadRepositoryLessons, :call, ->(**) { raise "boom" }) do
      stub_method(Rails.logger, :error, ->(message) { logged << message }) { charger("Develop") }
    end

    assert_includes output, "chargement automatique interrompu : RuntimeError : boom"
    assert_match(/interrompu : RuntimeError : boom/, logged.sole)
    assert_includes charger("Develop"), "loaded"
  end

  test "an author the policy refuses leaves the task saying so, without exception" do
    seed_referential

    output = stub_any_instance(Policies::Catalog::ManageContentPolicy, :call, ->(**) { Shared::Result.failure(:forbidden) }) { charger("Develop") }

    assert_includes output, "chargement refusé (forbidden)"
    assert_equal 0, Orm::Course.count
  end

  test "a lock that cannot be released is only logged" do
    seed_referential
    logged = []

    stub_method(Rails.logger, :error, ->(message) { logged << message }) do
      stub_any_instance(UseCases::Catalog::LoadRepositoryLessons, :call, ->(**) { Shared::Result.success(UseCases::Catalog::LoadRepositoryLessons::Summary.new(outcome: :skipped)) }) do
        connection = ActiveRecord::Base.connection
        stub_method(connection, :select_value, ->(sql) { sql.include?("unlock") ? raise("net") : true }) { charger("Develop") }
      end
    end

    assert_match(/verrou non rendu : RuntimeError : net/, logged.sole)
  ensure
    # Le verrou de session resterait pris sur la connexion partagée des tests.
    ActiveRecord::Base.connection.select_value(format(LOCK, "pg_advisory_unlock"))
  end
end
