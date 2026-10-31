require "test_helper"
require_relative "../support/environment_probe"

# ADR-0052 : the deployment is versioned, in .railway/railway.ts since railway.json stopped being read (chantier
# environnements-de-pr, lot A). Before each deploy, the database is prepared and the seeds
# run: in production, only db/seeds/identity.rb, which prints the bootstrap invitation of the first team member while
# none exists (ADR-0034, ADR-0038), and does nothing afterwards.
class RailwayDeploymentTest < ActiveSupport::TestCase
  BOOTSTRAP_LINK = %r{Invitation d'amorçage pour 0700000042, valable 72 h : /invitations/(\w+)}

  IAC = Rails.root.join(".railway/railway.ts")

  def pre_deploy_command = IAC.read[/preDeploy: "([^"]+)"/, 1].split

  def database_config = ActiveRecord::Base.connection_db_config.configuration_hash

  # Runs the pre-deploy command in production against `database`, as Railway does before each deploy.
  def deploy(database, environment_name: nil)
    config = database_config
    url = "postgres://#{config[:username]}:#{config[:password]}@#{config[:host]}:#{config[:port]}/#{database}"
    output, status = Open3.capture2e(
      EnvironmentProbe::BASE_ENV.merge("RAILS_ENV" => "production", "DATABASE_URL" => url, "TEAM_BOOTSTRAP_CONTACT" => "0700000042",
                                       "RAILWAY_ENVIRONMENT_NAME" => environment_name),
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

  # `railway config plan` says this file is what Railway applies in production, Staging and Develop (2026-10-23).
  test ".railway/railway.ts builds with the Dockerfile, prepares and seeds before deploying, checks /up, one branch per environment" do
    iac = IAC.read

    assert_includes iac, 'builder: "DOCKERFILE", dockerfilePath: "/Dockerfile"'
    assert_equal %w[bin/rails db:prepare db:seed], pre_deploy_command
    assert_includes iac, 'healthcheck: "/up"'
    { "production" => "main", "Staging" => "Staging", "Develop" => "Develop" }.each do |environment, branch|
      assert_match(/^\s*#{environment}: \{ branch: "#{branch}"/, iac, environment)
    end
    assert_not Rails.root.join("railway.json").exist?, "railway.json is no longer read by Railway: one source only"
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

  # Chantier contenus-develop-staging: the lesson loading rides on the same pre-deploy (`db:seed`), never fails it.
  test "the pre-deploy on a new database stays green and runs the lesson loading task: nothing to load without a name, no team member on Develop" do
    database = "lnclass_predeploy_#{SecureRandom.hex(4)}"

    silent = deploy(database)
    develop = deploy(database, environment_name: "Develop")

    assert_includes silent, "[contenus] environnement sans chargement automatique"
    assert_includes develop, "[contenus] aucun membre d'équipe actif"
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
