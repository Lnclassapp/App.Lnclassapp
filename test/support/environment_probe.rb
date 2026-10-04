require "json"
require "open3"

# Boots the application in another environment (production, development) in a
# child process and returns what `script` prints as JSON. The test process is
# locked to RAILS_ENV=test: only a child can prove what production does.
module EnvironmentProbe
  BASE_ENV = {
    "SECRET_KEY_BASE_DUMMY" => "1",
    "DATABASE_URL" => "postgres://probe:probe@127.0.0.1:1/probe", # never connected
    "BOOTSNAP_CACHE_DIR" => nil,
    "COVERAGE" => "0",
    # ADR-0047 : production refuses to boot without its bucket. Fake values, never contacted.
    "BUCKET_NAME" => "lnclass-probe",
    "BUCKET_ENDPOINT" => "https://t3.storageapi.dev",
    "BUCKET_ACCESS_KEY_ID" => "probe",
    "BUCKET_SECRET_ACCESS_KEY" => "probe"
  }.freeze

  def self.run(rails_env, script, env: {}) = run_with_output(rails_env, script, env:).first

  # → [what script prints, parsed ; everything the boot wrote (logs to STDOUT in production)].
  def self.run_with_output(rails_env, script, env: {})
    output, status = Open3.capture2e(
      BASE_ENV.merge("RAILS_ENV" => rails_env).merge(env),
      Rails.root.join("bin/rails").to_s, "runner", "puts JSON.generate(begin; #{script}; end)",
      chdir: Rails.root.to_s
    )
    raise "bin/rails runner (#{rails_env}) failed:\n#{output}" unless status.success?

    [ JSON.parse(output.lines.last), output ]
  end
end
