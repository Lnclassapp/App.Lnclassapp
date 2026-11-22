require "test_helper"
require "open3"
require "tmpdir"
require "yaml"

# Chantier demarrage-develop: Develop and Staging (deploy/hostinger/test.yaml) answer /up before their seeds run; the
# production (deploy/hostinger/compose.yaml) keeps preparing and seeding its base before Puma, as before.
class HostingerDemarrageTest < ActiveSupport::TestCase
  TEST_YAML = Rails.root.join("deploy/hostinger/test.yaml")
  PRODUCTION_YAML = Rails.root.join("deploy/hostinger/compose.yaml")
  ENTRYPOINT = Rails.root.join("bin/docker-entrypoint")

  def app_service(path) = YAML.load_file(path, aliases: true).fetch("services").fetch("app")

  test "the production keeps its entrypoint: db:prepare db:seed before Puma, nothing in the background" do
    app = app_service(PRODUCTION_YAML)
    script = app.fetch("entrypoint")[2]

    assert_equal "1", app.dig("environment", "PREPARE_DATABASE")
    assert script.end_with?('exec /rails/bin/docker-entrypoint "$$@"'), script
    assert_no_match(/db:seed|db:prepare|curl|démarrage|\)\s*&\s/, script)
    assert_includes ENTRYPOINT.read, %(if [ "${PREPARE_DATABASE}" == "1" ]; then\n  ./bin/rails db:prepare db:seed\nfi)
  end

  test "Develop and Staging prepare their base once, serve, then seed in the background once /up answers" do
    Dir.mktmpdir do |dir|
      log = File.join(dir, "log")
      fake(dir, "secrets/db_password", "secret")
      fake(dir, "bin/rails", %(echo "rails $*" >> #{log}; [ "$1" = db:seed ] && touch #{dir}/seeded; exit 0))
      fake(dir, "bin/thrust", %(echo "server" >> #{log}; touch #{dir}/up; i=0; while [ ! -f #{dir}/seeded ] && [ $i -lt 50 ]; do /bin/sleep 0.1; i=$((i+1)); done))
      fake(dir, "path/curl", %([ -f #{dir}/up ] || { echo "curl refused" >> #{log}; exit 7; }; echo "curl ok" >> #{log}))
      fake(dir, "path/sleep", "/bin/sleep 0.05")
      script = app_service(TEST_YAML).fetch("entrypoint")[2].gsub("$$", "$")
                                     .gsub("/secrets/", "#{dir}/secrets/").gsub("/rails/bin/docker-entrypoint", ENTRYPOINT.to_s)

      out, err, status = Open3.capture3({ "PATH" => "#{dir}/path:#{ENV.fetch('PATH')}" }, "sh", "-c", script, "sh",
                                         "./bin/thrust", "./bin/rails", "server", chdir: dir)
      wait_for { File.exist?(File.join(dir, "seeded")) }

      assert status.success?, err
      lines = File.readlines(log, chomp: true)
      assert_equal 1, lines.count("rails db:prepare"), lines.inspect
      assert_equal [ "rails db:prepare", "server", "curl ok", "rails db:seed" ], lines - [ "curl refused" ]
      stamp = /\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ/
      assert_match(/\[démarrage\] semis terminé #{stamp} \(conteneur démarré #{stamp}, \/up répond #{stamp}\)/, out)
    end
  end

  private

  def fake(dir, path, body)
    file = File.join(dir, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, path.start_with?("secrets/") ? body : "#!/bin/sh\n#{body}\n")
    File.chmod(0o755, file)
  end

  def wait_for
    50.times { return if yield; sleep 0.1 }
  end
end
