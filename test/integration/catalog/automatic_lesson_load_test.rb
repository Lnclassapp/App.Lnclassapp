require "test_helper"
require "rake"

# ADR chargement-automatique-des-lecons-hors-production : `bin/rails contenus:charger` sur une vraie base, avec le vrai fichier Thalès
# (4 sujets de devoir, deux exercices par notion). Les huit scénarios du PRD §4, puis la sûreté du démarrage (verrou, exception, pas d'équipe).
class Catalog::AutomaticLessonLoadTest < ActiveSupport::TestCase
  FILE = Rails.root.join("docs/contenus/lecons-traitees/3eme/mathematiques/proprietes-de-thales-dans-un-triangle.json")
  IMPORT_NAME = "chargement-automatique-3eme-mathematiques-proprietes-de-thales-dans-un-triangle.json"
  # Le nom de la ligne d'import d'un chargement entier (Develop, amendement du 2026-11-04).
  WHOLE_IMPORT_NAME = "chargement-automatique-entiere-3eme-mathematiques-proprietes-de-thales-dans-un-triangle.json"
  LOCK = "SELECT %s(hashtext('contenus:charger'))"
  # ADR-0123 : une leçon v3 du programme, sans sujet (Tle C).
  PROGRAMME_FILE = Rails.root.join("docs/contenus/lecons-traitees/tle-c/mathematiques/barycentre-et-lignes-de-niveaux.json")
  PROGRAMME_IMPORT_NAME = "chargement-automatique-tle-c-mathematiques-barycentre-et-lignes-de-niveaux.json"

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("contenus:charger")
    @document = JSON.parse(FILE.read)
    @lesson = @document["courses"].first
    @oldest = create_team_member(team_role: "content", second_factor: false)
    @oldest.update_columns(created_at: 10.days.ago)
    create_team_member(team_role: "admin", second_factor: false)
    create_team_member(team_role: "field", second_factor: false).update_columns(created_at: 20.days.ago, anonymized_at: 15.days.ago)
    # Le dépôt réduit à deux leçons : Thalès (sujets de devoir) et une leçon du programme v3, pour garder les tests courts.
    @root = Pathname(Dir.mktmpdir)
    { FILE => "3eme/mathematiques", PROGRAMME_FILE => "tle-c/mathematiques" }.each do |file, folder|
      @root.join(folder).mkpath
      FileUtils.cp(file, @root.join(folder))
    end
  end

  teardown { FileUtils.remove_entry(@root) }

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
    source = Repositories::Catalog::RepositoryLessonSource.new(root: @root)
    lessons = Repositories::Catalog::RepositoryLessonSource.instance_method(:lessons)
    stub_any_instance(Repositories::Catalog::RepositoryLessonSource, :lessons, -> { lessons.bind_call(source) }) do
      with_env(RAILWAY_ENVIRONMENT_NAME: environment, PR_BASE_ENVIRONMENT: nil, **env) { output, = capture_io { task.invoke } }
    end
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

  def automatic_reports(name = IMPORT_NAME) = Orm::ImportReport.where(kind: "course_tree").where("files @> ?::jsonb", [ { name: } ].to_json)
  def whole_reports = automatic_reports(WHOLE_IMPORT_NAME)

  def subject_exercise_count = @lesson["subjects"].sum { it["exercises"].size }

  # CA (ADR-0122) : sur Staging, une leçon à sujets publiée n'a que ses exercices et sujets remplacés
  test "Staging replaces the exercises and subjects of the published Thalès lesson, keeps its sheets, erases the student's session, and leaves a finished line" do
    seed_referential
    course = import_old_version
    notion = course.essentials.order(:position).first
    student = create_student
    session = create_exercise_session(student:, exercise: notion.exercises.first, status: "completed")
    create_attempt(session:, question: session.exercise.questions.first)
    sheets = course.essentials.order(:position).pluck(:slug, :name, :sheet)
    assert_equal 1, course.subjects.count

    output = charger("Staging")

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

  # CA (amendement du 2026-11-04) : sur Develop, la leçon à sujets (Thalès) est remplacée entière, sujets compris : Develop a exactement le fichier
  test "Develop replaces whole the published Thalès lesson: notions, sheets, exercises and subjects of the file; the student's work is erased" do
    seed_referential
    course = import_old_version
    course.essentials.order(:position).second.update_columns(name: "Autre nom")
    notion = course.essentials.order(:position).first
    student = create_student
    session = create_exercise_session(student:, exercise: notion.exercises.first, status: "completed")
    create_attempt(session:, question: session.exercise.questions.first)

    output = charger("Develop")

    assert_includes output, "#{IMPORT_NAME} : replaced"
    assert_not_includes output, "#{IMPORT_NAME} : loaded"
    course.reload
    assert_equal 1, Orm::Course.where(name: @lesson["name"]).count
    assert_equal [ "published" ], [ course.status ]
    assert_equal @lesson["notions"].map { it["name"].squish }, course.essentials.order(:position).pluck(:name)
    assert_equal @lesson["notions"].map { Array.wrap(it["exercise"]).size }, course.essentials.order(:position).map { it.exercises.count }
    assert_empty(course.essentials.flat_map { it.sheet.to_s.scan("Texte d'avant") })
    assert_equal @lesson["subjects"].map { it["title"] }, course.subjects.order(:position).pluck(:title)
    assert_equal [ "published" ], Orm::Exercise.where(course_id: course.id).distinct.pluck(:status)
    assert_equal [ 0, 0 ], [ Orm::ExerciseSession.count, Orm::QuestionAttempt.count ]
    assert_equal [ "completed", 1, 0 ], whole_reports.sole.values_at(:status, :imported_count, :error_count)
    assert_includes charger("Develop"), "#{IMPORT_NAME} : unchanged"
  end

  test "Develop creates the lesson whole when it is absent, then publishes it" do
    seed_referential

    assert_includes charger("Develop"), "#{IMPORT_NAME} : created"

    course = Orm::Course.find_by!(name: @lesson["name"])
    assert_equal [ "published" ], [ course.status ]
    assert_equal [ "published" ], course.essentials.distinct.pluck(:status)
    assert_equal [ "published" ], Orm::Exercise.where(course_id: course.id).distinct.pluck(:status)
    assert_equal 4, course.subjects.count
  end

  # standard-de-test §4.5 : Staging ajoute aussi les leçons v3 absentes du programme (create_only)
  test "Staging creates the lessons with subjects and the absent programme lessons, nothing else" do
    seed_referential

    charger("staging")

    assert_equal [ @lesson["name"], programme_lesson["name"] ].sort, Orm::Course.pluck(:name).sort
  end

  # CA : un fichier inchangé n'est pas rechargé
  test "an unchanged file is not loaded again: no new line" do
    seed_referential
    first = charger("Develop")

    second = charger("Develop")

    assert_includes first, "#{IMPORT_NAME} : created"
    assert_includes second, "#{IMPORT_NAME} : unchanged"
    assert_includes second, "#{PROGRAMME_IMPORT_NAME} : unchanged"
    assert_includes second, "2 leçon(s) examinée(s) : 0 créée(s), 0 ignorée(s) (déjà présente), 0 remplacée(s), 0 à sujets rechargée(s), 2 inchangée(s)"
    assert_equal [ 1, 0 ], [ whole_reports.count, automatic_reports.count ]
  end

  test "an unchanged file whose publication was interrupted is published again, without a new import line" do
    seed_referential
    charger("Develop")
    course = Orm::Course.find_by!(name: @lesson["name"])
    Orm::Exercise.where(course_id: course.id).first.update_columns(status: "draft", published_at: nil)

    output = charger("Develop")

    assert_includes output, "#{IMPORT_NAME} : republished"
    assert_equal [ "published" ], Orm::Exercise.where(course_id: course.id).distinct.pluck(:status)
    assert_equal 1, whole_reports.count
  end

  test "a changed file is loaded again, replaced whole on Develop" do
    seed_referential
    charger("Develop")
    whole_reports.update_all(checksum_sha256: "0" * 64)

    output = charger("Develop")

    assert_includes output, "#{IMPORT_NAME} : replaced"
    assert_includes output, "#{PROGRAMME_IMPORT_NAME} : unchanged"
    assert_equal 2, whole_reports.count
  end

  # Le premier déploiement après l'amendement : Develop avait chargé Thalès en « exercices et sujets » (même fichier, même empreinte).
  test "Develop replaces whole a lesson whose unchanged file was loaded exercises-only before, then says unchanged" do
    seed_referential
    course = import_old_version
    assert_includes charger("Staging"), "#{IMPORT_NAME} : loaded"
    course.essentials.order(:position).second.update_columns(name: "Autre nom")

    output = charger("Develop")

    assert_includes output, "#{IMPORT_NAME} : replaced"
    assert_equal @lesson["notions"].map { it["name"].squish }, course.reload.essentials.order(:position).pluck(:name)
    assert_empty(course.essentials.flat_map { it.sheet.to_s.scan("Texte d'avant") })
    assert_equal [ 1, 1 ], [ automatic_reports.count, whole_reports.count ]
    assert_includes charger("Develop"), "#{IMPORT_NAME} : unchanged"
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

  # CA (ADR-0122, Staging) : une notion introuvable refuse la leçon ; sur Develop la leçon est remplacée entière (test plus haut)
  test "on Staging a notion renamed in the environment refuses the lesson naming the notion, and no exercise or subject changes" do
    seed_referential
    course = import_old_version
    renamed = course.essentials.order(:position).second
    renamed.update_columns(name: "Autre nom")
    before = [ Orm::Exercise.where(course_id: course.id).pluck(:id).sort, course.subjects.pluck(:id).sort ]

    charger("Staging")

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
    assert_includes charger("Develop"), "#{IMPORT_NAME} : created"
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
    assert_includes charger("Develop"), "#{IMPORT_NAME} : created"
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

  # --- ADR-0123 : Develop remplace entières les leçons v3 du programme ---

  def programme_lesson = JSON.parse(PROGRAMME_FILE.read)["courses"].first

  # La leçon v1 du même titre, publiée, avec une fiche, un exercice et la séance d'un élève.
  def import_v1_programme_lesson
    level = Orm::Level.find_by!(name: "Tle")
    course = create_course(level:, material: Orm::Material.find_by!(name: "Mathématiques"), series: Orm::Series.find_by!(name: "C"),
                           name: programme_lesson["name"], status: "published", author: @oldest, content: "<p>Cours v1</p>")
    sheet = create_essential(course:, name: "Fiche v1")
    exercise = create_exercise(essential: sheet)
    create_exercise_session(student: create_student, exercise:, status: "completed")
    course
  end

  test "Develop replaces whole the published v1 lesson of the same title, publishes the v3 one, and says replaced; next time nothing" do
    seed_referential
    course = import_v1_programme_lesson

    output = charger("Develop")

    assert_includes output, "#{PROGRAMME_IMPORT_NAME} : replaced"
    course.reload
    assert_equal programme_lesson["notions"].map { it["name"].squish }, course.essentials.order(:position).pluck(:name)
    assert_equal [ "published" ], course.essentials.distinct.pluck(:status)
    assert_equal [ "published" ], Orm::Exercise.where(course_id: course.id).distinct.pluck(:status)
    assert_equal "published", course.status
    assert_equal 0, Orm::ExerciseSession.count
    assert_equal 1, Orm::Course.where(name: programme_lesson["name"]).count
    assert_includes charger("Develop"), "#{PROGRAMME_IMPORT_NAME} : unchanged"
  end

  test "Develop creates whole an absent programme lesson and says created" do
    seed_referential

    assert_includes charger("develop"), "#{PROGRAMME_IMPORT_NAME} : created"
    assert_equal "published", Orm::Course.find_by!(name: programme_lesson["name"]).status
  end

  test "Staging leaves the present v1 lesson of a programme title intact, says ignored; production loads nothing" do
    seed_referential
    course = import_v1_programme_lesson
    before = [ course.essentials.pluck(:id), Orm::Exercise.where(course_id: course.id).pluck(:id), Orm::ExerciseSession.count, course.reload.updated_at ]

    assert_includes charger("Staging"), "#{PROGRAMME_IMPORT_NAME} : ignored"
    assert_not_includes charger("production"), PROGRAMME_IMPORT_NAME

    assert_equal before, [ course.essentials.pluck(:id), Orm::Exercise.where(course_id: course.id).pluck(:id), Orm::ExerciseSession.count, course.reload.updated_at ]
    assert_equal "Cours v1", course.content.to_plain_text.squish
  end

  test "Staging creates an absent programme lesson and publishes it; the report counts created and ignored" do
    seed_referential

    output = charger("Staging")

    assert_includes output, "#{PROGRAMME_IMPORT_NAME} : created"
    assert_includes output, "2 leçon(s) examinée(s) : 1 créée(s), 0 ignorée(s) (déjà présente), 0 remplacée(s), 1 à sujets rechargée(s), 0 inchangée(s), 0 republiée(s), 0 en échec ou incomplète(s)"
    assert_equal "published", Orm::Course.find_by!(name: programme_lesson["name"]).status
  end

  # Amendement du 2026-11-04 : plus aucun environnement ne lit jeu.yml pour choisir les leçons.
  test "no environment reads the manifest any more: with jeu.yml unreadable, Develop and Staging load as usual and production says nothing" do
    seed_referential
    unreadable = ->(*) { raise Errno::ENOENT, "jeu.yml" }

    stub_method(Entities::Catalog::StandardTestSet, :new, unreadable) do
      assert_includes charger("production"), "rien n'est chargé"
      output = charger("Develop")
      assert_not_includes output, "interrompu"
      assert_includes output, "#{IMPORT_NAME} : created"
      assert_includes output, "#{PROGRAMME_IMPORT_NAME} : created"
      staging = charger("Staging")
      assert_includes staging, "#{IMPORT_NAME} : loaded"
      assert_includes staging, "#{PROGRAMME_IMPORT_NAME} : ignored"
    end
  end

  test "Develop loads every v3 file of every folder, 3ème included; a lesson without a file stays as it is" do
    seed_referential
    @root.join("tle-d/mathematiques").mkpath
    stranger = programme_lesson.merge("name" => "Leçon hors manifeste", "series_name" => "D")
    @root.join("tle-d/mathematiques/hors-manifeste.json").write(JSON.generate(@document.merge("courses" => [ stranger ])))
    third = programme_lesson.merge("name" => "Leçon de troisième", "level_name" => "3ème", "series_name" => nil)
    @root.join("3eme/mathematiques/sans-sujet.json").write(JSON.generate(@document.merge("courses" => [ third ])))
    present = create_course(level: Orm::Level.find_by!(name: "Tle"), material: Orm::Material.find_by!(name: "Mathématiques"), name: "Leçon ancienne",
                            status: "published", author: @oldest)

    output = charger("Develop")

    assert_includes output, "4 leçon(s) examinée(s) : 4 créée(s), 0 ignorée(s) (déjà présente), 0 remplacée(s), 0 à sujets rechargée(s), 0 inchangée(s), " \
                            "0 republiée(s), 0 en échec ou incomplète(s)"
    [ IMPORT_NAME, PROGRAMME_IMPORT_NAME, "chargement-automatique-tle-d-mathematiques-hors-manifeste.json",
      "chargement-automatique-3eme-mathematiques-sans-sujet.json" ].each { assert_includes output, "#{it} : created" }
    assert_equal "published", Orm::Course.find_by!(name: "Leçon hors manifeste").status
    assert_equal "published", Orm::Course.find_by!(name: "Leçon de troisième").status
    assert_equal [ "published", present.updated_at ], present.reload.values_at(:status, :updated_at)
  end

  test "Staging still does not load a 3ème lesson without subjects" do
    seed_referential
    third = programme_lesson.merge("name" => "Leçon de troisième", "level_name" => "3ème", "series_name" => nil)
    @root.join("3eme/mathematiques/sans-sujet.json").write(JSON.generate(@document.merge("courses" => [ third ])))

    output = charger("Staging")

    assert_not_includes output, "sans-sujet"
    assert_nil Orm::Course.find_by(name: "Leçon de troisième")
  end

  test "by hand, the published v1 lesson of a programme title is still refused" do
    seed_referential
    course = import_v1_programme_lesson
    report = create_import_report(kind: "course_tree", imported_by: @oldest)
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(io: StringIO.new(PROGRAMME_FILE.read), filename: "b.json") ])

    UseCases::Catalog::RunImport.new(
      adapter: Catalog::ImportCourseTreeJob.new.send(:adapter), reports: Repositories::Catalog::ImportReportRepository.new,
      files: Repositories::Catalog::ImportFileStore.new, schema: Repositories::Catalog::ImportSchemaValidator.new,
      users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
      transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    ).call(report_id: report.id)

    assert_equal [ "lesson_already_published" ], report.reload.import_errors.map { it["code"] }
    assert_equal [ "Fiche v1" ], course.essentials.pluck(:name)
  end

  # Le cas de Develop du 2026-11-02 : un référentiel sans le niveau Tle refuse chaque leçon du programme ; le journal dit pourquoi.
  test "Develop without the Tle level refuses the programme lesson and logs the code, the path and the level name" do
    seed_referential
    Orm::Level.where(name: "Tle").update_all(name: "Terminale", slug: "terminale")
    logged = []

    # Le complément du référentiel (ADR-0123 §8) est neutralisé : on regarde le journal d'un refus.
    nothing = -> { { levels: [], series: [], pairs: [], materials: [], plan_entries: [], drenas: [], conflicts: [], interruptions: [] } }
    output = stub_any_instance(Repositories::Catalog::ReferentialCompleter, :complete, nothing) do
      stub_method(Rails.logger, :warn, ->(message) { logged << message }) { charger("Develop") }
    end

    assert_includes output, "#{PROGRAMME_IMPORT_NAME} : refused"
    assert_includes logged, "[contenus] Barycentre et lignes de niveaux : import refusé (completed, 1 erreur(s)), voir Imports : " \
                            "unknown_level courses[0].level_name (value: Tle)"
  end

  # ADR-0123 §8 : le cas de Develop après #443 — référentiel sans le lycée ; Develop le complète, puis charge la leçon de Tle C.
  def college_referential
    create_level(name: "3ème", position: 4, cycle: "first")
    create_material(name: "Mathématiques", shortname: "Maths", category: "science")
  end

  test "Develop creates the missing levels, series, pairs and materials, then loads the Tle C lesson" do
    college_referential

    output = charger("Develop")

    assert_includes output, "#{PROGRAMME_IMPORT_NAME} : created"
    assert Orm::LevelSeries.exists?(level: Orm::Level.find_by!(slug: "tle"), series: Orm::Series.find_by!(slug: "c"))
    assert_equal [ 4, "first" ], Orm::Level.find_by!(slug: "3eme").then { [ it.position, it.cycle ] }
    assert Orm::Material.exists?(slug: "philosophie")
    assert Orm::Material.exists?(slug: "edhc")
    assert_equal 41, Orm::Drena.count
    assert Orm::ClassroomPlanEntry.exists?(level: Orm::Level.find_by!(slug: "tle"))
    assert_equal [ 0, 0 ], [ Orm::School.count, Orm::Classroom.count ]
  end

  test "Staging and production never create a level, a series or a material" do
    college_referential

    [ "Staging", "production" ].each { charger(it) }

    assert_equal [ 1, 0, 1, 0, 0 ], [ Orm::Level.count, Orm::Series.count, Orm::Material.count, Orm::Drena.count, Orm::ClassroomPlanEntry.count ]
  end

  # ADR-0123 §9 : le cas de Develop du 2026-11-02 — un déploiement a tué le chargement en pleine leçon ; le suivant, dans les 10 minutes,
  # trouve son rapport « en cours » : il le passe en échec et charge, au lieu de refuser chaque leçon (import déjà en cours).
  test "a report left running by a killed load does not block the next one, and the lesson is loaded" do
    seed_referential
    create_import_report(kind: "course_tree", imported_by: @oldest, status: "importing", files: [ { "name" => IMPORT_NAME, "byte_size" => 1 } ])

    output = charger("Develop")

    assert_includes output, "#{IMPORT_NAME} : created"
    assert_equal [ "failed" ], Orm::ImportReport.where(status: %w[failed]).pluck(:status)
    assert_equal 0, Orm::ImportReport.where(status: %w[queued validating importing]).count
  end
end
