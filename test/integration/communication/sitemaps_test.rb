require "test_helper"

module Communication
  # BL-19, BL-05 (ADR-0073 §4.6): /sitemap.xml and /robots.txt are served by routes, with absolute addresses on the
  # canonical host (config.x.canonical_host, never request.host) and a short cache — public/ is cached for a year.
  class SitemapsTest < ActionDispatch::IntegrationTest
    PAGES = Communication::PagesController
    SITEMAP_NS = { "s" => "http://www.sitemaps.org/schemas/sitemap/0.9" }.freeze

    setup do
      @online = PAGES.method(:online?)
      @canonical_host = Rails.configuration.x.canonical_host
    end

    teardown do
      PAGES.define_singleton_method(:online?, @online)
      Rails.configuration.x.canonical_host = @canonical_host
    end

    def sitemap_urls
      Nokogiri::XML(response.body).xpath("/s:urlset/s:url", SITEMAP_NS).map do |url|
        [ url.at_xpath("s:loc", SITEMAP_NS).text, url.at_xpath("s:lastmod", SITEMAP_NS)&.text ]
      end
    end

    test "the sitemap lists the homepage, /aide, every online public page, /blog and every published article with its date" do
      older = create_article(title: "Réviser le bac", published_at: Time.zone.local(2026, 9, 1, 8))
      newer = create_article(title: "La rentrée", published_at: Time.zone.local(2026, 9, 20, 8))
      older.update_columns(updated_at: Time.zone.local(2026, 9, 25, 10, 30))
      newer.update_columns(updated_at: Time.zone.local(2026, 9, 21, 9))

      get sitemap_path

      assert_response :success
      assert_equal "application/xml", response.media_type
      # Rails writes the directives of « public, max-age=3600 » (ADR-0073 §4.6) in its own order.
      assert_equal "max-age=3600, public", response.headers["Cache-Control"]
      assert_equal [ [ "https://lnclass.com/", nil ],
                     [ "https://lnclass.com/aide", nil ],
                     [ "https://lnclass.com/mission", nil ],
                     [ "https://lnclass.com/confidentialite", nil ],
                     [ "https://lnclass.com/conditions-utilisation", nil ],
                     [ "https://lnclass.com/conditions-vente", nil ],
                     [ "https://lnclass.com/blog", nil ],
                     [ "https://lnclass.com/blog/la-rentree", "2026-09-21T09:00:00Z" ],
                     [ "https://lnclass.com/blog/reviser-le-bac", "2026-09-25T10:30:00Z" ] ],
                   sitemap_urls
    end

    test "the sitemap is a valid urlset document" do
      get sitemap_path

      document = Nokogiri::XML(response.body)
      assert_empty document.errors
      assert_equal "UTF-8", document.encoding
      assert_equal "urlset", document.root.name
      assert_equal SITEMAP_NS["s"], document.root.namespace.href
    end

    test "neither a draft nor an archived article is in the sitemap (BL-05, BL-19)" do
      published = create_article(title: "En ligne")
      create_article(status: "draft", title: "Brouillon secret")
      create_article(status: "archived", title: "Article retiré")

      get sitemap_path

      article_urls = sitemap_urls.map(&:first).grep(%r{/blog/})
      assert_equal [ "https://lnclass.com/blog/#{published.slug}" ], article_urls
      assert_no_match(/brouillon-secret|article-retire/, response.body)
    end

    test "a public page that is not online is not in the sitemap" do
      PAGES.define_singleton_method(:online?) { |page| page.to_sym != :terms }

      get sitemap_path

      urls = sitemap_urls.map(&:first)
      assert_includes urls, "https://lnclass.com/mission"
      assert_not_includes urls, "https://lnclass.com/conditions-utilisation"
    end

    test "the addresses follow the canonical host, never the host of the request" do
      Rails.configuration.x.canonical_host = "www.lnclass.com"
      create_article(title: "La rentrée")

      get sitemap_path, headers: { "HOST" => "example.org" }

      assert sitemap_urls.map(&:first).all? { it.start_with?("https://www.lnclass.com/") }, response.body
      assert_includes sitemap_urls.map(&:first), "https://www.lnclass.com/blog/la-rentree"
      assert_no_match(/example\.org/, response.body)
    end

    test "a signed-in student reads the same sitemap, without being sent to their home" do
      sign_in_as create_student

      get sitemap_path

      assert_response :success
      assert_equal "https://lnclass.com/", sitemap_urls.first.first
    end

    test "robots.txt allows every robot and points to the sitemap on the canonical host" do
      get robots_path

      assert_response :success
      assert_equal "text/plain", response.media_type
      assert_equal "max-age=86400, public", response.headers["Cache-Control"]
      assert_equal <<~ROBOTS, response.body
        # See https://www.robotstxt.org/robotstxt.html for documentation on how to use the robots.txt file
        User-agent: *
        Disallow:

        Sitemap: https://lnclass.com/sitemap.xml
      ROBOTS
    end

    test "CANONICAL_HOST changes the Sitemap line without touching the code" do
      Rails.configuration.x.canonical_host = "www.lnclass.com"

      get robots_path, headers: { "HOST" => "example.org" }

      assert_includes response.body.lines, "Sitemap: https://www.lnclass.com/sitemap.xml\n"
      assert_no_match(/example\.org/, response.body)
    end

    test "neither public/robots.txt nor public/sitemap.xml exist: they would shadow the routes with a one-year cache" do
      %w[robots.txt sitemap.xml].each do |file|
        assert_not Rails.public_path.join(file).exist?, "public/#{file} est servi avant la route : supprime-le (ADR-0073 §4.6)"
      end
      assert_equal "/robots.txt", robots_path
      assert_equal "/sitemap.xml", sitemap_path
    end

    test "the public responses set no session cookie" do
      get sitemap_path
      assert_nil response.headers["Set-Cookie"]

      get robots_path
      assert_nil response.headers["Set-Cookie"]
    end
  end
end
