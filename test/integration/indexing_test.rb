require "test_helper"

# ADR-0074, amendement du 2026-10-07 : seule la production (lnclass.com, www.lnclass.com) s'indexe. Toute réponse d'un
# autre hôte porte X-Robots-Tag, quel que soit CANONICAL_HOST : une variable oubliée n'ouvre pas Staging aux moteurs.
class IndexingTest < ActionDispatch::IntegrationTest
  NOINDEX = "noindex, nofollow".freeze

  test "the production hosts are indexed: no X-Robots-Tag on a public page" do
    %w[lnclass.com www.lnclass.com].each do |host|
      [ root_path, blog_path, help_path ].each do |path|
        get path, headers: { "HOST" => host }

        assert_response :success
        assert_nil response.headers["X-Robots-Tag"], "#{host}#{path}"
      end
    end
  end

  test "every other host is closed to search engines, on public pages, the sign-in page and robots.txt" do
    %w[app-staging.lnclass.com app-develop.lnclass.com applnclassapp-staging-b274.up.railway.app www.example.com].each do |host|
      [ root_path, blog_path, help_path, new_session_path, robots_path ].each do |path|
        get path, headers: { "HOST" => host }

        assert_response :success
        assert_equal NOINDEX, response.headers["X-Robots-Tag"], "#{host}#{path}"
      end
    end
  end

  test "a redirect off production is closed too" do
    get student_home_path, headers: { "HOST" => "app-staging.lnclass.com" }

    assert_response :redirect
    assert_equal NOINDEX, response.headers["X-Robots-Tag"]
  end
end
