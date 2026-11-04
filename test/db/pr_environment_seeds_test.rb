require "test_helper"

# ADR-0108, ADR-0034: a PR environment (Railway, run in production) is seeded like development plus the three test
# schools of the standard test set (two lessons of its manifest); production without the PR variables keeps the identity seed alone. Played in the
# transaction of the test, with two lessons instead of the 47 of the manifest (STANDARD_LESSONS_LIMIT).
class PrEnvironmentSeedsTest < ActiveSupport::TestCase
  PR_VARIABLES = { "PR_BASE_ENVIRONMENT" => "Develop", "RAILWAY_ENVIRONMENT_NAME" => "lnclass-pr-276" }.freeze
  TABLES = [ Orm::Drena, Orm::School, Orm::Classroom, Orm::Level, Orm::Series, Orm::LevelSeries, Orm::ClassroomPlanEntry,
             Orm::Material, Orm::User, Orm::Course, Orm::ClassroomStudent, Orm::TeacherClassroom ].freeze
  TEST_FILES = %w[catalog school development standard].freeze
  MANIFEST = Entities::Catalog::StandardTestSet.new(YAML.load_file(Rails.root.join("db/seeds/standard/jeu.yml")))
  LESSONS = MANIFEST.expected_paths.first(2).map { Rails.root.join("docs/contenus/lecons-traitees", it) }.freeze

  def counts = TABLES.to_h { [ it.name, it.count ] }

  # Wrapped load: the top-level constants of the seed files stay in an anonymous module.
  def run_seeds
    previous = ENV.values_at("STANDARD_LESSONS_LIMIT", "STANDARD_ACTIVITY_SIZE")
    ENV["STANDARD_LESSONS_LIMIT"] = LESSONS.size.to_s
    ENV["STANDARD_ACTIVITY_SIZE"] = "reduite"
    capture_io { load Rails.root.join("db/seeds.rb").to_s, true }.first
  ensure
    ENV["STANDARD_LESSONS_LIMIT"], ENV["STANDARD_ACTIVITY_SIZE"] = previous
  end

  # Routes are drawn before the switch (config/routes.rb reads Rails.env), as in SeedsTest.
  def as_production(variables)
    Rails.application.reload_routes_unless_loaded
    previous = variables.keys.to_h { [ it, ENV[it] ] }
    previous.each_key { ENV.delete(it) }
    variables.each { |key, value| ENV[key] = value }
    Rails.env = "production"
    yield
  ensure
    Rails.env = "test"
    previous.each { |key, value| ENV[key] = value }
  end

  test "a PR environment gets the referential, the DRENA, the development accounts and the three standard schools" do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    as_production(PR_VARIABLES) { run_seeds }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    warn "[pr-seeds] semis d'un environnement de PR : #{elapsed.round(1)} s"

    assert_equal 41, Orm::Drena.count
    assert_equal %w[6eme 5eme 4eme 3eme 2nde 1ere tle], Orm::Level.order(:position).pluck(:slug)
    assert_equal 6, Orm::Material.where.not(slug: "edhc").count
    assert Orm::User.exists?(contact: "0700000000", role: "team")
    assert Orm::Course.exists?(name: "La cellule")
    assert_equal 3, Orm::School.where("name LIKE ?", "%Modèle%").count
    assert Orm::School.exists?(name: "Lycée Moderne de Treichville")
    assert Orm::User.find_by!(contact: "0500000011").authenticate_pin("2468")
    assert Orm::User.find_by!(contact: "0700000010").authenticate_pin("2468")
    LESSONS.each do |path|
      course = Orm::Course.find_by!(name: JSON.parse(path.read)["courses"].first["name"])
      assert_equal "published", course.status, path.to_s
      assert_operator course.essentials.where(status: "published").count, :>=, 1, path.to_s
    end
  end

  test "a second run creates nothing" do
    as_production(PR_VARIABLES) { run_seeds }
    first = counts

    as_production(PR_VARIABLES) { run_seeds }

    assert_equal first, counts
  end

  test "production without the PR variables seeds the identity alone and the test files refuse to run" do
    before = counts

    as_production({}) do
      run_seeds
      TEST_FILES.each do |name|
        error = assert_raises(RuntimeError) { load Rails.root.join("db/seeds/#{name}.rb").to_s, true }
        assert_match "db/seeds/#{name}.rb est réservé", error.message
      end
    end

    assert_equal before, counts
  end

  test "a base environment alone, or a name equal to it, is not a PR environment" do
    before = counts

    as_production({ "PR_BASE_ENVIRONMENT" => "Develop", "RAILWAY_ENVIRONMENT_NAME" => "Develop" }) { run_seeds }

    assert_equal before, counts
  end
end
