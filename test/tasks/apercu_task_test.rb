require "test_helper"
require "rake"

# Chantier standard-de-test, Lot E : `bin/rails contenus:apercu[fichier]`. Le vrai fichier Thalès (3ème) et la vraie chaîne d'import ;
# l'environnement est joué en développement le temps d'un appel (le test tourne en `test`, que la tâche refuse comme tout autre).
class ApercuTaskTest < ActiveSupport::TestCase
  LESSONS = "docs/contenus/lecons-traitees".freeze
  FILE = "#{LESSONS}/3eme/mathematiques/proprietes-de-thales-dans-un-triangle.json".freeze
  OTHER = "#{LESSONS}/tle-c/mathematiques/barycentre-et-lignes-de-niveaux.json".freeze

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("contenus:apercu")
    seed_referential
    @author = create_team_member(team_role: "content", second_factor: false)
    @document = JSON.parse(Rails.root.join(FILE).read)
    @lesson = @document["courses"].first
  end

  # → [sortie, erreur, SystemExit ou nil]
  def apercu(path, environment: "development")
    task = Rake::Task["contenus:apercu"]
    task.reenable
    exit_error = nil
    out, err = capture_io do
      with_rails_env(environment) { task.invoke(path) }
    rescue SystemExit => e
      exit_error = e
    end
    [ out, err, exit_error ]
  end

  def with_rails_env(name)
    original = Rails.method(:env)
    Rails.define_singleton_method(:env) { ActiveSupport::EnvironmentInquirer.new(name) }
    yield
  ensure
    Rails.define_singleton_method(:env, original)
  end

  # Importe un document par la chaîne ordinaire (brouillon) et rend son cours.
  def import_document(document)
    report = create_import_report(kind: "course_tree", imported_by: @author)
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(io: StringIO.new(document.to_json), filename: "lecon.json") ])
    UseCases::Catalog::RunImport.new(
      adapter: Catalog::ImportCourseTreeJob.new.send(:adapter), reports: Repositories::Catalog::ImportReportRepository.new,
      files: Repositories::Catalog::ImportFileStore.new, schema: Repositories::Catalog::ImportSchemaValidator.new,
      users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
      transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    ).call(report_id: report.id)
    Orm::Course.find_by!(name: document["courses"].first["name"])
  end

  # La leçon "d'avant" : un seul sujet de devoir.
  def import_old_version
    old = @document.deep_dup
    old["courses"].first["subjects"] = old["courses"].first["subjects"].first(1)
    import_document(old)
  end

  # Écrit une variante de la leçon dans le dossier des leçons, le temps du test ; rend son chemin relatif.
  def write_variant(name, document)
    path = Rails.root.join(LESSONS, "3eme", "mathematiques", name)
    path.write(JSON.generate(document))
    (@variants ||= []) << path
    path.relative_path_from(Rails.root).to_s
  end

  teardown { Array(@variants).each { it.delete if it.exist? } }

  test "refuses outside development and imports nothing" do
    %w[production test staging].each do |environment|
      out, err, exit_error = apercu(FILE, environment:)

      assert exit_error, "#{environment} doit être refusé"
      assert_match(/development/, err)
      assert_empty out
    end
    assert_equal 0, Orm::Course.count
  end

  test "refuses a path outside docs/contenus/lecons-traitees and imports nothing" do
    outside = Pathname(Dir.mktmpdir).join("lecon.json")
    outside.write(Rails.root.join(FILE).read)
    [ "config/routes.rb", "#{LESSONS}/../../../config/database.yml", outside.to_s, "#{LESSONS}/3eme/absente.json", LESSONS, "" ].each do |path|
      _, err, exit_error = apercu(path)

      assert exit_error, "#{path.inspect} doit être refusé"
      assert_match(/lecons-traitees/, err)
    end
    assert_equal 0, Orm::Course.count
  ensure
    FileUtils.remove_entry(outside.dirname) if outside
  end

  test "refuses a symbolic link that leaves the lessons folder" do
    link = Rails.root.join(LESSONS, "3eme", "lien-de-test.json")
    File.symlink(Rails.root.join("config/routes.rb"), link)
    @variants = [ link ]

    _, err, exit_error = apercu("#{LESSONS}/3eme/lien-de-test.json")

    assert exit_error
    assert_match(/lecons-traitees/, err)
  end

  test "imports and publishes this one file only, and prints the lesson address" do
    out, _, exit_error = apercu(FILE)

    assert_nil exit_error
    assert_equal [ @lesson["name"] ], Orm::Course.pluck(:name)
    course = Orm::Course.sole
    assert_equal "published", course.status
    assert_equal [ "published" ], Orm::Exercise.where(course_id: course.id).distinct.pluck(:status)
    assert_equal [ "published" ], course.essentials.distinct.pluck(:status)
    assert_includes out, "/courses/#{course.slug}"
  end

  test "replaces the lesson of the same title and leaves the other lessons alone" do
    course = import_old_version
    other_course = import_document(JSON.parse(Rails.root.join(OTHER).read))
    assert_equal 1, course.subjects.count

    _, _, exit_error = apercu(FILE)

    assert_nil exit_error
    assert_equal @lesson["subjects"].size, course.reload.subjects.count
    assert_equal "published", course.status
    assert_equal "draft", other_course.reload.status
    assert_equal 2, Orm::Course.count
  end

  test "an invalid JSON stops at the validator, prints its errors and leaves the database untouched" do
    course = import_old_version
    before = [ course.subjects.pluck(:id), course.essentials.pluck(:id), Orm::Exercise.count ]
    broken = @document.deep_dup
    broken["courses"].first["notions"].first.delete("exercise")

    out, _, exit_error = apercu(write_variant("apercu-test-refuse.json", broken))

    assert exit_error
    assert_match(/✗/, out)
    assert_equal before, [ course.reload.subjects.pluck(:id), course.essentials.pluck(:id), Orm::Exercise.count ]
  end

  test "a file the import refuses but the validator accepts leaves the database untouched" do
    course = import_old_version
    before = [ course.subjects.pluck(:id), Orm::Exercise.count ]
    unknown = @document.deep_dup
    unknown["courses"].first["material_name"] = "Matière inconnue"

    _, err, exit_error = apercu(write_variant("apercu-test-inconnue.json", unknown))

    assert exit_error
    assert_match(/refus/i, err)
    assert_equal before, [ course.reload.subjects.pluck(:id), Orm::Exercise.count ]
  end
end
