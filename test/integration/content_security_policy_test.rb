require "test_helper"

# ADR-0049 : strict CSP, blocking, no third party.
class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  # Turbo adds this header to every request it makes (visit, form, frame).
  TURBO = { "X-Turbo-Request-Id" => "visit" }.freeze

  test "every page is served under a strict CSP that trusts no third party" do
    [ root_path, "/teams/jobs" ].each do |path|
      get path

      csp = response.headers["Content-Security-Policy"]
      assert csp, "#{path} : la CSP doit être bloquante (pas Report-Only)"
      assert_match(/default-src 'self'/, csp)
      assert_match(/object-src 'none'/, csp)
      assert_match(/frame-ancestors 'none'/, csp)
      script_src = csp[/script-src [^;]*/]
      refute_match(/unsafe-inline|unsafe-eval|https?:/, script_src)
      assert_match(/'nonce-/, script_src, "#{path} : les scripts en ligne passent par un nonce")
    end
  end

  # Amendment of 2026-09-26: a Turbo Drive visit keeps the CSP of the first page, so the nonce holds for the session.
  test "the nonce holds for the whole session, and a new session draws a new one" do
    student = create_student(classroom: create_classroom)
    anonymous = 2.times.map { get(new_session_path) && nonce }
    assert_equal 1, anonymous.uniq.size
    assert_equal anonymous.first, meta_nonce, "la balise meta porte le nonce de l'en-tête"

    sign_in_as student
    follow_redirect!
    signed_in = nonce
    assert_not_equal anonymous.first, signed_in
    get courses_path
    assert_equal signed_in, nonce

    sign_out
    follow_redirect!
    assert_not_equal signed_in, nonce
  end

  test "a Turbo visit to the page reached right after a new session reloads the document once, and keeps its toast for it" do
    sign_in_as create_student(classroom: create_classroom)
    follow_redirect!(headers: TURBO.dup)
    assert_select "meta[name=turbo-visit-control][content=reload]"
    assert_select "#toasts", text: /#{I18n.t("identity.sessions.create.signed_in")}/

    get student_home_path
    assert_select "meta[name=turbo-visit-control]", count: 0
    assert_select "#toasts", text: /#{I18n.t("identity.sessions.create.signed_in")}/

    get student_home_path
    assert_select "#toasts", text: /#{I18n.t("identity.sessions.create.signed_in")}/, count: 0

    sign_out
    follow_redirect!(headers: TURBO.dup)
    assert_select "meta[name=turbo-visit-control][content=reload]"
  end

  test "a page loaded without Turbo after a new session already has its CSP: no reload" do
    sign_in_as create_student(classroom: create_classroom)
    follow_redirect!
    assert_select "meta[name=turbo-visit-control]", count: 0
    assert_select "#toasts", text: /#{I18n.t("identity.sessions.create.signed_in")}/

    get student_home_path
    assert_select "#toasts", text: /#{I18n.t("identity.sessions.create.signed_in")}/, count: 0
  end

  private

  def nonce = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
  def meta_nonce = css_select("meta[name=csp-nonce]").first["content"]
end
