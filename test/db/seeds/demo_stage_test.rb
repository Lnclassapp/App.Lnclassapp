require "test_helper"
require Rails.root.join("config/demo_environment").to_s

# Chantier standard-de-test, Lot H : db:seed sur l'environnement Demo charge le référentiel et le jeu standard, rien d'autre.
# Les comptes équipe n'existent que si DEMO_TEAM_PIN est posée : un PIN public sur un compte équipe d'un site ouvert
# donnerait l'administration à tout visiteur.
class DemoStageTest < ActiveSupport::TestCase
  KEYS = %w[RAILWAY_ENVIRONMENT_NAME PR_BASE_ENVIRONMENT DEMO_TEAM_PIN STANDARD_TEAM_PIN STANDARD_LESSONS_LIMIT TEAM_BOOTSTRAP_CONTACT].freeze

  def seed(team_pin: nil)
    previous = ENV.values_at(*KEYS)
    ENV.update("RAILWAY_ENVIRONMENT_NAME" => "Demo", "PR_BASE_ENVIRONMENT" => "Develop", "DEMO_TEAM_PIN" => team_pin,
               "STANDARD_LESSONS_LIMIT" => "2", "STANDARD_TEAM_PIN" => "1111", "TEAM_BOOTSTRAP_CONTACT" => nil)
    capture_io { load Rails.root.join("db/seeds.rb").to_s, true }
  ensure
    KEYS.zip(previous) { |key, value| ENV[key] = value }
  end

  def school_names
    identity = Entities::School::FictitiousIdentity.new(YAML.load_file(Rails.root.join("db/seeds/standard/noms.yml")))
    set = Entities::Catalog::StandardTestSet.new(YAML.load_file(Rails.root.join("db/seeds/standard/jeu.yml")))
    set.schools.map { identity.school_name(it.key) }
  end

  def team_users = Orm::User.where(role: "team").where.not(contact: "0700000000")

  test "the seed loads the referential and the standard set, without lecons_completes" do
    seed

    assert_operator Orm::Level.count, :>, 0
    assert_equal 3, Orm::School.where(name: school_names).count
    assert_equal 2, Orm::Course.where(status: "published").count
  end

  test "no usable team account without DEMO_TEAM_PIN, whatever STANDARD_TEAM_PIN says" do
    seed

    # Seul l'administrateur inerte qui publie les leçons existe : PIN aléatoire, aucun second facteur.
    assert_operator team_users.count, :<=, 1
    assert team_users.none? { |user| %w[2468 1111].any? { |pin| user.authenticate_pin(pin) } }
    assert_equal 0, Orm::TotpCredential.where(user_id: team_users.select(:id)).count
  end

  test "team accounts exist with DEMO_TEAM_PIN as their PIN" do
    seed(team_pin: "9753")

    assert_equal 3, team_users.count
    assert team_users.all? { it.authenticate_pin("9753") }
    assert team_users.none? { it.authenticate_pin("2468") || it.authenticate_pin("1111") }
  end

  test "a second seed creates no duplicate" do
    seed(team_pin: "9753")
    counts = [ Orm::User.count, Orm::School.count, Orm::Classroom.count, Orm::Course.count ]
    seed(team_pin: "9753")

    assert_equal counts, [ Orm::User.count, Orm::School.count, Orm::Classroom.count, Orm::Course.count ]
  end
end
