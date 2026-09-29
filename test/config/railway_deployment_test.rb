require "test_helper"
require_relative "../support/environment_probe"

# ADR-0052 : the deployment is versioned in railway.json. Before each deploy, the database is prepared and the seeds
# run: in production, only db/seeds/identity.rb, which prints the bootstrap invitation of the first team member while
# none exists (ADR-0034, ADR-0038), and does nothing afterwards.
class RailwayDeploymentTest < ActiveSupport::TestCase
  BOOTSTRAP_LINK = %r{Invitation d'amorçage pour 0700000042, valable 72 h : /invitations/(\w+)}

  def pre_deploy_command = JSON.parse(Rails.root.join("railway.json").read).dig("deploy", "preDeployCommand").sole.split

  def database_config = ActiveRecord::Base.connection_db_config.configuration_hash

  # Runs the pre-deploy command in production against `database`, as Railway does before each deploy.
  def deploy(database)
    config = database_config
    url = "postgres://#{config[:username]}:#{config[:password]}@#{config[:host]}:#{config[:port]}/#{database}"
    output, status = Open3.capture2e(
      EnvironmentProbe::BASE_ENV.merge("RAILS_ENV" => "production", "DATABASE_URL" => url, "TEAM_BOOTSTRAP_CONTACT" => "0700000042"),
      *pre_deploy_command, chdir: Rails.root.to_s
    )
    assert status.success?, output
    output
  end

  def drop(database)
    config = database_config
    connection = PG.connect(host: config[:host], port: config[:port], user: config[:username], password: config[:password],
                            dbname: "postgres")
    connection.exec("DROP DATABASE IF EXISTS #{connection.quote_ident(database)}")
    connection.close
  end

  test "railway.json builds with the Dockerfile, prepares and seeds the database before deploying, and checks /up" do
    config = JSON.parse(Rails.root.join("railway.json").read)

    assert_equal({ "builder" => "DOCKERFILE", "dockerfilePath" => "Dockerfile" }, config["build"])
    assert_equal [ "bin/rails db:prepare db:seed" ], config.dig("deploy", "preDeployCommand")
    assert_equal "/up", config.dig("deploy", "healthcheckPath")
  end

  # Production, 2026-09-29: on a new database, db:prepare loaded the schema and seeded, then db:seed seeded again in the
  # same process; two links were printed per deploy, the first one already revoked by the second.
  test "on a new database, each deploy seeds once and prints a single bootstrap link, which a later deploy replaces" do
    database = "lnclass_predeploy_#{SecureRandom.hex(4)}"

    first = deploy(database)
    second = deploy(database)

    assert_equal 1, first.scan(BOOTSTRAP_LINK).size, first
    assert_no_match "already initialized constant", first
    assert_equal 1, second.scan(BOOTSTRAP_LINK).size, second
    assert_not_equal first[BOOTSTRAP_LINK, 1], second[BOOTSTRAP_LINK, 1]
  ensure
    drop(database)
  end

  test "db:prepare seeds a new database in development and test, never in production, where db:seed alone does" do
    seeds = EnvironmentProbe.run("production", 'ActiveRecord::Base.configurations.configs_for(env_name: "production").map(&:seeds?)')

    assert_equal [ false ], seeds
    assert_equal [ true ], ActiveRecord::Base.configurations.configs_for(env_name: "development").map(&:seeds?)
    assert_equal [ true ], ActiveRecord::Base.configurations.configs_for(env_name: "test").map(&:seeds?)
  end
end
