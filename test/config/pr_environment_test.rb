require "test_helper"
require Rails.root.join("config/pr_environment").to_s

# ADR-XXXX : a PR environment is recognised by PR_BASE_ENVIRONMENT, set and different from RAILWAY_ENVIRONMENT_NAME,
# and is closed by a shared password, except /up.
class PrEnvironmentTest < ActiveSupport::TestCase
  def active?(base, name) = PrEnvironment.active?({ "PR_BASE_ENVIRONMENT" => base, "RAILWAY_ENVIRONMENT_NAME" => name }.compact)

  test "an environment named differently from the base is a PR environment" do
    assert active?("Develop", "lnclass-pr-276")
  end

  test "the base environment itself is not a PR environment" do
    assert_not active?("Develop", "Develop")
  end

  test "without the base variable, or with it blank, never a PR environment" do
    assert_not active?(nil, "lnclass-pr-276")
    assert_not active?("", "lnclass-pr-276")
    assert_not active?("  ", "lnclass-pr-276")
  end

  test "without a current environment name, never a PR environment" do
    assert_not active?("Develop", nil)
    assert_not active?("Develop", " ")
  end

  test "surrounding spaces are ignored when comparing the names" do
    assert_not active?(" Develop ", "Develop")
    assert active?("Develop", " lnclass-pr-276 ")
  end

  test "it reads the process environment by default" do
    assert_not PrEnvironment.active?, "the test environment carries no PR variable"
  end

  # --- the gate ---

  def gate(password: "secret") = PrEnvironment::Gate.new(->(_env) { [ 200, {}, [ "page" ] ] }, password:)

  def get(path, gate: gate(), password: nil)
    headers = {}
    headers["HTTP_AUTHORIZATION"] = ActionController::HttpAuthentication::Basic.encode_credentials("anyone", password) if password
    Rack::MockRequest.new(gate).get(path, headers)
  end

  test "a page without a password is refused with a browser prompt" do
    response = get("/")

    assert_equal 401, response.status
    assert_equal 'Basic realm="Lnclass PR"', response.headers["www-authenticate"]
    assert_no_match(/page/, response.body)
  end

  test "a page with a wrong password is refused" do
    assert_equal 401, get("/mission", password: "wrong").status
  end

  test "a page with the right password is served, whatever the user name" do
    response = get("/mission", password: "secret")

    assert_equal 200, response.status
    assert_equal "page", response.body
  end

  test "/up answers without a password" do
    assert_equal 200, get("/up").status
  end

  test "without PR_ACCESS_PASSWORD, everything but /up is refused, whatever the password given" do
    [ nil, "", "  " ].each do |missing|
      closed = gate(password: missing)

      assert_equal 401, get("/", gate: closed).status
      assert_equal 401, get("/", gate: closed, password: "").status
      assert_equal 401, get("/", gate: closed, password: "anything").status
      assert_equal 200, get("/up", gate: closed).status
    end
  end

  test "the password is read from PR_ACCESS_PASSWORD by default" do
    previous = ENV["PR_ACCESS_PASSWORD"]
    ENV["PR_ACCESS_PASSWORD"] = "from-env"
    open_gate = PrEnvironment::Gate.new(->(_env) { [ 200, {}, [ "page" ] ] })

    assert_equal 200, get("/", gate: open_gate, password: "from-env").status
    assert_equal 401, get("/", gate: open_gate, password: "secret").status
  ensure
    previous.nil? ? ENV.delete("PR_ACCESS_PASSWORD") : ENV["PR_ACCESS_PASSWORD"] = previous
  end

  test "a malformed Authorization header is refused, not an error" do
    response = Rack::MockRequest.new(gate).get("/", "HTTP_AUTHORIZATION" => "Basic !!!not-base64")

    assert_equal 401, response.status
  end
end
