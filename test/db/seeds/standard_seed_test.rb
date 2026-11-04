require "test_helper"
require "open3"

# ADR standard-de-test §4 points 1 à 3 : le jeu de base se charge en une commande, sans doublon, par la vraie chaîne d'import.
# Les leçons sont limitées à 2 (STANDARD_LESSONS_LIMIT) pour tenir sous 20 s : le manifeste complet se mesure avec bin/jeu-standard.
class StandardSeedTest < ActiveSupport::TestCase
  LIMIT = 2
  SEEDS = Rails.root.join("db/seeds/standard")
  TABLES = [ Orm::School, Orm::Classroom, Orm::User, Orm::ClassroomStudent, Orm::TeacherSchool, Orm::TeacherClassroom, Orm::Course ].freeze

  setup do
    @manifest = YAML.load_file(SEEDS.join("jeu.yml"))
    @set = Entities::Catalog::StandardTestSet.new(@manifest)
    @identity = Entities::School::FictitiousIdentity.new(YAML.load_file(SEEDS.join("noms.yml")))
    %w[catalog school].each { load Rails.root.join("db/seeds/#{it}.rb").to_s, true }
  end

  def counts = TABLES.to_h { [ it.name, it.count ] }

  def run_seed(team_pin: nil)
    previous = ENV.values_at("STANDARD_LESSONS_LIMIT", "STANDARD_TEAM_PIN")
    ENV["STANDARD_LESSONS_LIMIT"] = LIMIT.to_s
    ENV["STANDARD_TEAM_PIN"] = team_pin
    capture_io { load Rails.root.join("db/seeds/standard.rb").to_s, true }
  ensure
    ENV["STANDARD_LESSONS_LIMIT"], ENV["STANDARD_TEAM_PIN"] = previous
  end

  test "two loads create no duplicate" do
    run_seed
    first = counts
    output = run_seed.first

    assert_equal first, counts
    assert_no_match "déjà pris", output
    assert_equal 3, Orm::School.where(name: @set.schools.map { @identity.school_name(it.key) }).count
    assert_equal @set.classrooms.size, Orm::Classroom.where(school_id: Orm::School.where(name: @set.schools.map { @identity.school_name(it.key) })).count
  end

  test "the published lessons are the first ones of the manifest" do
    run_seed

    names = @set.expected_paths.first(LIMIT).map do |path|
      JSON.parse(Rails.root.join("docs/contenus/lecons-traitees", path).read).fetch("courses").first.fetch("name")
    end
    assert_equal names.sort, Orm::Course.where(name: names, status: "published").pluck(:name).sort
  end

  test "a teacher serves the lycee and the college, the empty class is empty, the full one holds 40 students" do
    run_seed

    index = @set.accounts.teachers.index { it.key == "multi-mathematiques" }
    multi = Orm::User.find_by!(contact: @identity.contact(role: :teacher, index: index + 10))
    assert_equal 2, Orm::TeacherSchool.where(teacher_id: multi.id).count
    assert multi.authenticate_pin("2468")
    assert_equal 0, students_of("college", "5eme")
    assert_equal 40, students_of("lycee", "tle-d")
    assert_operator students_of("lycee", "tle-a1"), :>, 0
    assert_equal 1500, Orm::ClassroomStudent.where(classroom_id: classroom_ids_of("grand")).count
  end

  test "every contact is in the fictitious range and the team has accounts with the PIN of the test" do
    run_seed

    contacts = Orm::User.where.not(contact: "0700000000").pluck(:contact)
    assert contacts.all? { @identity.fictitious_contact?(it) }
    assert_equal 3, Orm::User.where(role: "team").where.not(contact: "0700000000").count
  end

  test "the team accounts follow STANDARD_TEAM_PIN" do
    run_seed(team_pin: "9753")

    admin = Orm::User.find_by!(contact: @identity.contact(role: :admin, index: 0))
    assert admin.authenticate_pin("9753")
    assert_not admin.authenticate_pin("2468")
  end

  # Un compte déjà là sur un contact du jeu, mais qui n'est pas celui du jeu (autre rôle ou autre nom), n'est jamais modifié :
  # ni PIN, ni rôle, ni rattachement à une classe ou un établissement du jeu ; il est signalé dans le journal du semis.
  test "an existing account on a contact of the set is left untouched and reported" do
    stranger = Orm::User.create!(contact: @identity.contact(role: :student, index: 10), role: "teacher", first_name: "Réel",
                                 last_name: "Testeur", gender: "female", pin: "1357")
    output = run_seed.first

    stranger.reload
    assert_equal "teacher", stranger.role
    assert stranger.authenticate_pin("1357")
    assert_not Orm::ClassroomStudent.exists?(student_id: stranger.id)
    assert_not Orm::TeacherSchool.exists?(teacher_id: stranger.id)
    assert_match "#{stranger.contact[0, 2]}******#{stranger.contact[-2..]} déjà pris par un autre compte", output
    assert_no_match stranger.contact, output
  end

  test "another account on the contact of the admin of the set never publishes in its place" do
    Orm::User.create!(contact: @identity.contact(role: :admin, index: 0), role: "team", team_role: "admin", first_name: "Autre",
                      last_name: "Admin", gender: "female", pin: "1357")
    error = assert_raises(RuntimeError) { run_seed }

    assert_match "administrateur du jeu est pris par un autre compte", error.message
    assert_equal 0, Orm::Course.where(status: "published").count
  end

  test "a broken manifest stops the load before anything is created" do
    broken = @manifest.merge("lecons" => @manifest.fetch("lecons").merge("6eme/svt" => "absent.json"))
    file = Tempfile.new([ "jeu", ".yml" ])
    file.write(broken.to_yaml)
    file.close
    ENV["STANDARD_MANIFEST"] = file.path
    error = assert_raises(RuntimeError) { run_seed }
    assert_match "manifeste du jeu standard invalide", error.message
    assert_match "fichier absent du dépôt : 6eme/svt/absent.json", error.message
    assert_equal 0, Orm::School.where(name: @set.schools.map { @identity.school_name(it.key) }).count
  ensure
    ENV.delete("STANDARD_MANIFEST")
    file&.unlink
  end

  test "a reset on a remote environment is refused without confirmation, and nothing is deleted" do
    before = Orm::User.count
    out, status = Open3.capture2e({ "RAILWAY_ENVIRONMENT_NAME" => "develop" }, "bin/jeu-standard", "--reset", chdir: Rails.root.to_s)

    assert_not status.success?
    assert_match "--confirmer=develop", out
    assert_equal before, Orm::User.count
  end

  test "a reset is refused when DATABASE_URL is set, whatever the confirmation, and nothing is deleted" do
    before = Orm::User.count
    env = { "DATABASE_URL" => "postgres://autre-hote.example/base", "RAILWAY_ENVIRONMENT_NAME" => "develop" }
    out, status = Open3.capture2e(env, "bin/jeu-standard", "--reset", "--confirmer=develop", chdir: Rails.root.to_s)

    assert_not status.success?
    assert_match "DATABASE_URL", out
    assert_equal before, Orm::User.count
  end

  test "a non integer STANDARD_LESSONS_LIMIT is an explicit error" do
    ENV["STANDARD_LESSONS_LIMIT"] = "beaucoup"
    error = assert_raises(RuntimeError) { capture_io { load Rails.root.join("db/seeds/standard.rb").to_s, true } }
    assert_match "STANDARD_LESSONS_LIMIT", error.message
    assert_equal 0, Orm::School.where(name: @set.schools.map { @identity.school_name(it.key) }).count
  ensure
    ENV.delete("STANDARD_LESSONS_LIMIT")
  end

  private

  def school_of(key) = Orm::School.find_by!(name: @identity.school_name(key))
  def classroom_ids_of(school_key) = Orm::Classroom.where(school_id: school_of(school_key).id).pluck(:id)

  def students_of(school_key, classroom_key)
    spec = @set.classrooms.find { it.school == school_key && it.key == classroom_key }
    classroom = Orm::Classroom.find_by!(school_id: school_of(school_key).id, level: Orm::Level.find_by!(slug: spec.level),
                                        series: spec.series && Orm::Series.find_by!(slug: spec.series))
    Orm::ClassroomStudent.where(classroom_id: classroom.id).count
  end
end
