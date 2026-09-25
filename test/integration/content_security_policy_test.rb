require "test_helper"

# ADR-0049 : strict CSP, blocking, no third party.
class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
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

  test "the nonce changes on every request" do
    nonces = 2.times.map do
      get root_path
      response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
    end

    assert_equal 2, nonces.uniq.size
  end
end
