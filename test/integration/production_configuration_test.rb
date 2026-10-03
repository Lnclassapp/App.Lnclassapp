require "test_helper"
require_relative "../support/environment_probe"

# Garde-fou n° 6 de la V0 : production settings, proven on a real production boot.
class ProductionConfigurationTest < ActiveSupport::TestCase
  # Rack requests against the production application, in a child process.
  PROBE = <<~RUBY
    app = Rails.application
    call = ->(url) { Rack::MockRequest.new(app).get(url, "HTTP_HOST" => URI(url).host) }
    {
      "assume_ssl" => app.config.assume_ssl,
      "force_ssl" => app.config.force_ssl,
      "http_page" => call.("http://lnclass.up.railway.app/mission").then { |r| [ r.status, r.headers["strict-transport-security"].to_s ] },
      "redirect_excludes" => %w[/up /].map { |path| app.config.ssl_options.dig(:redirect, :exclude).call(ActionDispatch::Request.new(Rack::MockRequest.env_for(path))) },
      "http_up" => call.("http://healthcheck.railway.app/up").status,
      "unknown_host" => call.("https://evil.example.org/").status,
      "custom_host" => call.("https://lnclass.app/up").status,
      "hosts" => app.config.hosts.map(&:to_s),
      "queue_adapter" => app.config.active_job.queue_adapter.to_s,
      "csp" => call.("https://lnclass.up.railway.app/up").headers["content-security-policy"].to_s,
      "default_locale" => I18n.default_locale.to_s,
      "raise_on_missing_translations" => app.config.i18n.raise_on_missing_translations
    }
  RUBY

  RAILWAY = { "RAILWAY_PUBLIC_DOMAIN" => "lnclass.up.railway.app", "APP_HOSTS" => "lnclass.app, www.lnclass.app" }.freeze

  def production
    @@production ||= EnvironmentProbe.run("production", PROBE, env: RAILWAY)
  end

  test "SSL is assumed behind Railway's proxy and enforced by HSTS on every page" do
    assert production["assume_ssl"]
    assert production["force_ssl"]

    # A static public page: the probe's database is never connected, and the homepage now reads it (« Blog » link, UDR-0064).
    status, hsts = production["http_page"]
    assert_equal 200, status, "derrière le proxy Railway, une requête est traitée comme HTTPS"
    assert_match(/max-age=\d+/, hsts)
  end

  test "the health check is excluded from the HTTPS redirection" do
    assert_equal [ true, false ], production["redirect_excludes"]
  end

  test "/up answers over plain HTTP, from Railway's own host" do
    assert_equal 200, production["http_up"]
  end

  test "hosts come from Railway and APP_HOSTS, any other host is refused" do
    assert_equal %w[lnclass.up.railway.app lnclass.app www.lnclass.app], production["hosts"]
    assert_equal 403, production["unknown_host"]
    assert_equal 200, production["custom_host"]
  end

  test "without any host variable, production fails closed to localhost" do
    hosts = EnvironmentProbe.run("production", "Rails.application.config.hosts.map(&:to_s)")

    assert_equal [ "localhost" ], hosts
  end

  test "a canonical host that production does not serve is warned about at boot, once; a served one is not" do
    warning = "CANONICAL_HOST lnclass.com is not in config.hosts"
    _, unserved = EnvironmentProbe.run_with_output("production", "true", env: RAILWAY)
    _, served = EnvironmentProbe.run_with_output("production", "true", env: RAILWAY.merge("CANONICAL_HOST" => "www.lnclass.app"))

    assert_equal 1, unserved.scan(warning).size, unserved
    assert_no_match(/is not in config\.hosts/, served)
  end

  test "jobs go to Solid Queue" do
    assert_equal "solid_queue", production["queue_adapter"]
  end

  test "the CSP is enforced in production too" do
    assert_match(/default-src 'self'/, production["csp"])
  end

  test "the interface speaks French and production never raises on a missing key" do
    assert_equal "fr", production["default_locale"]
    assert_not production["raise_on_missing_translations"]
  end
end
