# ADR-0031 (amendement 2026-09-29): a response that shows a one-time secret stays out of every cache —
# no-store for the browser and any proxy, and a Turbo cache exemption in the page head.
module SecretResponseAssertions
  ActionDispatch::IntegrationTest.include(self)

  TURBO_NO_CACHE = "meta[name=turbo-cache-control][content=no-cache]".freeze

  # stream: the Turbo Stream response adds the exemption to the head of the page that hosts it.
  def assert_secret_response(stream: false)
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "no-cache", response.headers["Pragma"]
    if stream
      assert_select "turbo-stream[action=append][targets=head] template #{TURBO_NO_CACHE}", 1
    else
      assert_select "head #{TURBO_NO_CACHE}", 1
    end
  end

  def assert_not_secret_response
    assert_not_equal "no-store", response.headers["Cache-Control"]
    assert_nil response.headers["Pragma"]
    assert_select TURBO_NO_CACHE, 0
  end
end
