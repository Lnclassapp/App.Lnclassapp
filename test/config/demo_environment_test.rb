require "test_helper"
require Rails.root.join("config/demo_environment").to_s

# Chantier standard-de-test, Lot H : l'environnement Railway nommé Demo (demo.lnclass.com) est un stade à part.
class DemoEnvironmentTest < ActiveSupport::TestCase
  def active?(name) = DemoEnvironment.active?({ "RAILWAY_ENVIRONMENT_NAME" => name }.compact)

  test "an environment named Demo is the demo environment, whatever the case and the spaces" do
    [ "Demo", "demo", "DEMO", " Demo " ].each { assert active?(it), it }
  end

  test "any other name, or none, is not the demo environment" do
    [ "Develop", "Staging", "production", "demo-2", "lnclass-pr-12", "", "  ", nil ].each { assert_not active?(it), it.inspect }
  end

  test "the variables of the base environment do not change the answer" do
    assert DemoEnvironment.active?({ "RAILWAY_ENVIRONMENT_NAME" => "Demo", "PR_BASE_ENVIRONMENT" => "Develop" })
  end
end
