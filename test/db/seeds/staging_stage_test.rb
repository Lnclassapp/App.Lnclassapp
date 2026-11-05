require "test_helper"
require "rake"

# Chantier comptes-de-test-staging, Lot A (ADR-0124 §9) : db:seed sur Staging (Rails production, RAILWAY_ENVIRONMENT_NAME=Staging) ajoute les
# établissements, classes et comptes du jeu standard, sans activité simulée ni leçon du manifeste (Staging garde son chargement :create_only,
# contenus:charger, stubé ici). Les comptes équipe n'existent qu'avec STANDARD_TEAM_PIN (scellée). La production ne sème aucun jeu.
class StagingStageTest < ActiveSupport::TestCase
  KEYS = %w[RAILWAY_ENVIRONMENT_NAME PR_BASE_ENVIRONMENT DEMO_TEAM_PIN STANDARD_TEAM_PIN STANDARD_LESSONS_LIMIT TEAM_BOOTSTRAP_CONTACT
            STANDARD_ACTIVITY_SIZE].freeze
  SEEDS = Rails.root.join("db/seeds/standard")

  setup do
    @set = Entities::Catalog::StandardTestSet.new(YAML.load_file(SEEDS.join("jeu.yml")))
    @identity = Entities::School::FictitiousIdentity.new(YAML.load_file(SEEDS.join("noms.yml")))
    %w[catalog school].each { load Rails.root.join("db/seeds/#{it}.rb").to_s, true }
    Rails.application.load_tasks unless Rake::Task.task_defined?("contenus:charger")
  end

  def seed(name: "Staging", team_pin: nil)
    previous = ENV.values_at(*KEYS)
    ENV.update("RAILWAY_ENVIRONMENT_NAME" => name, "PR_BASE_ENVIRONMENT" => nil, "DEMO_TEAM_PIN" => "8642",
               "STANDARD_LESSONS_LIMIT" => nil, "STANDARD_TEAM_PIN" => team_pin, "TEAM_BOOTSTRAP_CONTACT" => nil,
               "STANDARD_ACTIVITY_SIZE" => "reduite")
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
  def teacher_contact = @identity.contact(role: :teacher, index: 10)
  def counts = [ Orm::User, Orm::School, Orm::Classroom, Orm::ClassroomStudent, Orm::TeacherSchool, Orm::SchoolStaff, Orm::Course ].map(&:count)

  test "Staging receives the schools, classrooms and accounts of the set, with no activity and no lesson of the manifest" do
    output = seed

    assert_equal 3, jeu_schools.count
    assert_equal @set.classrooms.size, Orm::Classroom.where(school_id: jeu_schools.select(:id)).count
    assert Orm::User.find_by!(contact: teacher_contact).authenticate_pin("2468")
    assert Orm::SchoolStaff.exists?(user_id: Orm::User.find_by!(contact: @identity.contact(role: :direction, index: 10)).id)
    assert_operator Orm::ClassroomStudent.where(classroom_id: Orm::Classroom.where(school_id: jeu_schools.select(:id)).select(:id)).count, :>, 1500
    assert_equal 0, Orm::ExerciseSession.count
    assert_equal 0, Orm::ClassroomAssignment.count
    assert_equal 0, Orm::Course.count
    assert_includes output, "[contenus] stub"
    assert_includes output, "laissées au chargement de Staging"
  end

  test "no team account without STANDARD_TEAM_PIN, and the three with it, with no second factor nobody holds" do
    seed
    assert_equal 0, team_users.count

    seed(team_pin: "9753")
    assert_equal 3, team_users.count
    assert team_users.all? { it.authenticate_pin("9753") }
    assert team_users.none? { it.authenticate_pin("2468") }
    assert_equal 0, Orm::TotpCredential.where(user_id: team_users.select(:id)).where.not(confirmed_at: nil).count
  end

  test "a second seed creates nothing twice" do
    seed(team_pin: "9753")
    before = counts
    output = seed(team_pin: "9753")

    assert_equal before, counts
    assert_no_match "déjà pris", output
  end

  test "an account holding a contact of the set is neither modified nor attached, and is reported masked" do
    stranger = Orm::User.create!(contact: teacher_contact, role: "teacher", first_name: "Vraie", last_name: "Testeuse", gender: "female", pin: "1357")
    output = seed

    stranger.reload
    assert_equal [ "teacher", "Vraie" ], [ stranger.role, stranger.first_name ]
    assert stranger.authenticate_pin("1357")
    assert_not Orm::TeacherSchool.exists?(teacher_id: stranger.id)
    assert_match "#{stranger.contact[0, 2]}******#{stranger.contact[-2..]} déjà pris par un autre compte", output
    assert_no_match stranger.contact, output
  end

  test "a failure of the set never fails the deploy of Staging: it is printed and logged" do
    logged = []
    stub_method(Rails.logger, :error, ->(message) { logged << message }) do
      stub_method(Entities::Catalog::StandardTestSet, :new, ->(*) { raise "boom" }) { @output = seed }
    end

    assert_includes @output, "[standard] semis impossible sur Staging : RuntimeError : boom"
    assert logged.one? { it.start_with?("[standard] semis impossible sur Staging : RuntimeError : boom\n") && it.include?("db/seeds/standard.rb") }
  end

  test "production receives nothing of the set" do
    seed(name: "production", team_pin: "9753")

    assert_equal 0, jeu_schools.count
    assert_equal 0, Orm::User.where(contact: teacher_contact).count
    assert_equal 0, team_users.count
  end
end
