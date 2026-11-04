# Chantier standard-de-test, Lot H: the Railway environment named Demo (demo.lnclass.com) is a stage of its own.
# Plain Ruby, nothing else required: loaded next to config/pr_environment.rb (config/puma.rb, then config/application.rb).
module DemoEnvironment
  NAME = "demo".freeze

  # Only the name of the environment decides, case and spaces ignored. Demo is never a PR environment (PrEnvironment),
  # even when PR_BASE_ENVIRONMENT was copied into it from Develop.
  def self.active?(env = ENV)
    env["RAILWAY_ENVIRONMENT_NAME"].to_s.strip.downcase == NAME
  end
end
