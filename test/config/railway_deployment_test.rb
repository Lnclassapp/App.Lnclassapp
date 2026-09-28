require "test_helper"

# ADR-0052 : the deployment is versioned in railway.json. Before each deploy, the database is prepared and the seeds
# run: in production, only db/seeds/identity.rb, which prints the bootstrap invitation of the first team member while
# none exists (ADR-0034, ADR-0038), and does nothing afterwards.
class RailwayDeploymentTest < ActiveSupport::TestCase
  test "railway.json builds with the Dockerfile, prepares and seeds the database before deploying, and checks /up" do
    config = JSON.parse(Rails.root.join("railway.json").read)

    assert_equal({ "builder" => "DOCKERFILE", "dockerfilePath" => "Dockerfile" }, config["build"])
    assert_equal [ "bin/rails db:prepare db:seed" ], config.dig("deploy", "preDeployCommand")
    assert_equal "/up", config.dig("deploy", "healthcheckPath")
  end
end
