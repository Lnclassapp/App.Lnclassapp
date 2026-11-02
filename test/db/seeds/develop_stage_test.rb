require "test_helper"
require "rake"

# Chantier standard-de-test, Lot I : db:seed sur Develop (Rails production, RAILWAY_ENVIRONMENT_NAME=Develop) ajoute les établissements,
# classes et comptes du jeu standard, sans rien supprimer ni modifier. Les leçons du manifeste restent à contenus:charger (ADR-0122/0123),
# stubé ici. Les comptes équipe n'existent qu'avec STANDARD_TEAM_PIN (scellée) : jamais de PIN public sur un site ouvert.
class DevelopStageTest < ActiveSupport::TestCase
  KEYS = %w[RAILWAY_ENVIRONMENT_NAME PR_BASE_ENVIRONMENT DEMO_TEAM_PIN STANDARD_TEAM_PIN STANDARD_LESSONS_LIMIT TEAM_BOOTSTRAP_CONTACT].freeze
  SEEDS = Rails.root.join("db/seeds/standard")

  setup do
    @set = Entities::Catalog::StandardTestSet.new(YAML.load_file(SEEDS.join("jeu.yml")))
    @identity = Entities::School::FictitiousIdentity.new(YAML.load_file(SEEDS.join("noms.yml")))
    # Le référentiel et les DRENA de Develop (complétés par contenus:charger, ADR-0123 §8).
    %w[catalog school].each { load Rails.root.join("db/seeds/#{it}.rb").to_s, true }
    Rails.application.load_tasks unless Rake::Task.task_defined?("contenus:charger")
  end

  def seed(name: "Develop", team_pin: nil)
    previous = ENV.values_at(*KEYS)
    ENV.update("RAILWAY_ENVIRONMENT_NAME" => name, "PR_BASE_ENVIRONMENT" => nil, "DEMO_TEAM_PIN" => "8642",
               "STANDARD_LESSONS_LIMIT" => nil, "STANDARD_TEAM_PIN" => team_pin, "TEAM_BOOTSTRAP_CONTACT" => nil)
    stub_method(Rake::Task["contenus:charger"], :invoke, ->(*) { puts "[contenus] stub" }) do
      as_production { capture_io { load Rails.root.join("db/seeds.rb").to_s, true }.first }
    end
  ensure
    KEYS.zip(previous) { |key, value| ENV[key] = value }
  end

  def as_production
    Rails.application.reload_routes_unless_loaded
    Rails.env = "production"
    yield
  ensure
    Rails.env = "test"
  end

  def school_names = @set.schools.map { @identity.school_name(it.key) }
  def jeu_schools = Orm::School.where(name: school_names)
  def team_users = Orm::User.where(role: "team")
  def counts = [ Orm::User, Orm::School, Orm::Classroom, Orm::ClassroomStudent, Orm::TeacherSchool, Orm::SchoolStaff, Orm::Course ].map(&:count)

  test "Develop receives the schools, classrooms and accounts of the set, and imports no lesson" do
    output = seed

    assert_equal 3, jeu_schools.count
    assert_equal @set.classrooms.size, Orm::Classroom.where(school_id: jeu_schools.select(:id)).count
    teacher = Orm::User.find_by!(contact: @identity.contact(role: :teacher, index: 10))
    head = Orm::User.find_by!(contact: @identity.contact(role: :direction, index: 10))
    assert teacher.authenticate_pin("2468")
    assert Orm::SchoolStaff.exists?(user_id: head.id)
    assert_operator Orm::ClassroomStudent.where(classroom_id: Orm::Classroom.where(school_id: jeu_schools.select(:id)).select(:id)).count, :>, 1500
    assert_equal 0, Orm::Course.count
    assert_includes output, "[contenus] stub"
  end

  test "a second seed creates nothing twice" do
    seed
    before = counts
    output = seed

    assert_equal before, counts
    assert_no_match "déjà pris", output
  end

  test "existing data of Develop is kept: schools, published lessons, and an account on a contact of the set" do
    other = create_school(name: "Test — Lycée de l'équipe")
    course = create_course(status: "published")
    stranger = Orm::User.create!(contact: @identity.contact(role: :teacher, index: 10), role: "teacher", first_name: "Vraie",
                                 last_name: "Testeuse", gender: "female", pin: "1357")
    output = seed

    assert Orm::School.exists?(other.id)
    assert_equal "published", course.reload.status
    stranger.reload
    assert_equal [ "teacher", "Vraie" ], [ stranger.role, stranger.first_name ]
    assert stranger.authenticate_pin("1357")
    assert_not Orm::TeacherSchool.exists?(teacher_id: stranger.id)
    assert_not Orm::TeacherProfile.exists?(user_id: stranger.id)
    assert_match "#{stranger.contact[0, 2]}******#{stranger.contact[-2..]} déjà pris par un autre compte", output
    assert_no_match stranger.contact, output
  end

  # Un établissement réel qui porte le nom d'un établissement du jeu n'est jamais repris : le jeu n'est pas semé, c'est signalé.
  test "a real school holding the name of a school of the set is left alone, and the set is not seeded" do
    real = create_school(name: @identity.school_name("lycee"))
    output = seed

    assert_equal 0, Orm::SchoolStaff.where(school_id: real.id).count
    assert_equal 0, Orm::Classroom.where(school_id: real.id).count
    assert_equal 0, Orm::User.where(contact: @identity.contact(role: :teacher, index: 10)).count
    assert_includes output, "[standard] semis impossible sur Develop"
    assert_includes output, @identity.school_name("lycee")
    assert_equal 1, jeu_schools.count
  end

  test "a later seed never rewrites an account of the set already there" do
    seed(team_pin: "9753")
    admin = team_users.first
    teacher = Orm::User.find_by!(contact: @identity.contact(role: :teacher, index: 10))
    [ admin, teacher ].each { it.update!(pin: "1470") }
    seed(team_pin: "1111")

    assert [ admin, teacher ].all? { it.reload.authenticate_pin("1470") }
  end

  test "outside the set, a failing seed still fails the deploy of Develop" do
    stub_method(Rake::Task["contenus:charger"], :invoke, ->(*) { raise "boom" }) do
      ENV["RAILWAY_ENVIRONMENT_NAME"] = "Develop"
      error = assert_raises(RuntimeError) { as_production { capture_io { load Rails.root.join("db/seeds/catalog.rb").to_s, true } } }
      assert_match "réservé", error.message
    end
  ensure
    ENV.delete("RAILWAY_ENVIRONMENT_NAME")
  end

  test "the standard seed refuses Staging and production by itself" do
    [ "Staging", "production" ].each do |name|
      ENV["RAILWAY_ENVIRONMENT_NAME"] = name
      error = assert_raises(RuntimeError) { as_production { capture_io { load Rails.root.join("db/seeds/standard.rb").to_s, true } } }
      assert_match "est réservé", error.message
    end
  ensure
    ENV.delete("RAILWAY_ENVIRONMENT_NAME")
  end

  test "no team account on Develop without STANDARD_TEAM_PIN, whatever DEMO_TEAM_PIN says, and never the public PIN" do
    seed

    assert_equal 0, team_users.count
  end

  test "with STANDARD_TEAM_PIN, the team accounts take it, with no second factor nobody holds" do
    seed(team_pin: "9753")

    assert_equal 3, team_users.count
    assert team_users.all? { it.authenticate_pin("9753") }
    assert team_users.none? { it.authenticate_pin("2468") }
    assert_equal 0, Orm::TotpCredential.where(user_id: team_users.select(:id)).where.not(confirmed_at: nil).count
  end

  test "Staging and production receive nothing of the set" do
    [ "Staging", "production" ].each { seed(name: it) }

    assert_equal 0, jeu_schools.count
    assert_equal 0, Orm::User.where(contact: @identity.contact(role: :teacher, index: 10)).count
  end

  test "a failure of the set never fails the deploy of Develop: it is printed and logged" do
    logged = []
    stub_method(Rails.logger, :error, ->(message) { logged << message }) do
      stub_method(Entities::Catalog::StandardTestSet, :new, ->(*) { raise "boom" }) { @output = seed }
    end

    assert_includes @output, "[standard] semis impossible sur Develop : RuntimeError : boom"
    assert logged.one? { it.start_with?("[standard] semis impossible sur Develop : RuntimeError : boom\n") && it.include?("db/seeds/standard.rb") }
  end
end
