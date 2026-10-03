require "test_helper"

# ADR-0074 §6, UDR-0066 §3.1, UDR-0067 §3.0 : les routes du blog sont le contrat des lots A, B, D et E. Elles sont
# dessinées avant leurs contrôleurs : on reconnaît une route sans charger son contrôleur.
class BlogRoutesTest < ActionDispatch::IntegrationTest
  def helpers = Rails.application.routes.url_helpers

  # Routes are drawn lazily (Rails 8) and the router alone does not draw them: `routes` does.
  def first_match(path, method: "GET")
    Rails.application.routes.routes
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for(path, method:))
    Rails.application.routes.router.recognize(request) { |_route, params| return params.except(:format).symbolize_keys }
    nil
  end

  test "les adresses publiques : la liste, un article par son slug, une image par son public_id, le plan du site, robots.txt" do
    assert_equal [ "/blog", "/blog/reviser-le-bepc", "/blog/images/abcdefghijkmno", "/sitemap.xml", "/robots.txt" ],
                 [ helpers.blog_path, helpers.blog_article_path("reviser-le-bepc"), helpers.blog_image_path("abcdefghijkmno"),
                   helpers.sitemap_path, helpers.robots_path ]
    assert_equal "/blog?page=2", helpers.blog_path(page: 2)

    { "/blog" => { controller: "communication/articles", action: "index" },
      "/blog/reviser-le-bepc" => { controller: "communication/articles", action: "show", slug: "reviser-le-bepc" },
      "/blog/images/abcdefghijkmno" => { controller: "communication/article_images", action: "show", public_id: "abcdefghijkmno" },
      "/sitemap.xml" => { controller: "communication/sitemaps", action: "show" },
      "/robots.txt" => { controller: "communication/sitemaps", action: "robots" } }.each do |path, target|
      assert_equal target, first_match(path), path
    end
  end

  test "le plan du site répond en XML et robots.txt en texte" do
    Rails.application.routes.routes
    request = ->(path) { ActionDispatch::Request.new(Rack::MockRequest.env_for(path)) }
    formats = [ "/sitemap.xml", "/robots.txt" ].map do |path|
      Rails.application.routes.router.recognize(request.(path)) { |_route, params| break params[:format] }
    end

    assert_equal %i[xml text], formats
  end

  test "les adresses de l'équipe : liste, création, modification, publication, archivage, envoi d'image" do
    assert_equal [ "/teams/blog", "/teams/blog/new", "/teams/blog/abcdefghijkmno/edit", "/teams/blog/abcdefghijkmno",
                   "/teams/blog/abcdefghijkmno/publish", "/teams/blog/abcdefghijkmno/archive", "/teams/blog/images",
                   "/teams/blog/images?article=abcdefghijkmno" ],
                 [ helpers.teams_articles_path, helpers.new_teams_article_path, helpers.edit_teams_article_path("abcdefghijkmno"),
                   helpers.teams_article_path("abcdefghijkmno"), helpers.publish_teams_article_path("abcdefghijkmno"),
                   helpers.archive_teams_article_path("abcdefghijkmno"), helpers.teams_article_images_path,
                   helpers.teams_article_images_path(article: "abcdefghijkmno") ]

    { [ "/teams/blog", "GET" ] => { action: "index" }, [ "/teams/blog/new", "GET" ] => { action: "new" },
      [ "/teams/blog", "POST" ] => { action: "create" },
      [ "/teams/blog/abcdefghijkmno/edit", "GET" ] => { action: "edit", public_id: "abcdefghijkmno" },
      [ "/teams/blog/abcdefghijkmno", "PATCH" ] => { action: "update", public_id: "abcdefghijkmno" },
      [ "/teams/blog/abcdefghijkmno/publish", "PATCH" ] => { action: "publish", public_id: "abcdefghijkmno" },
      [ "/teams/blog/abcdefghijkmno/archive", "PATCH" ] => { action: "archive", public_id: "abcdefghijkmno" } }.each do |(path, method), target|
      assert_equal({ controller: "teams/articles", **target }, first_match(path, method:), "#{method} #{path}")
    end
    assert_equal({ controller: "teams/article_images", action: "create" }, first_match("/teams/blog/images", method: "POST"))
  end

  test "un chemin fixe n'est jamais capturé par un public_id ni par un slug ; ni suppression, ni lecture d'un article de l'équipe" do
    assert_equal({ controller: "teams/articles", action: "new" }, first_match("/teams/blog/new"))
    assert_equal({ controller: "teams/article_images", action: "create" }, first_match("/teams/blog/images", method: "POST"))
    assert_equal({ controller: "communication/article_images", action: "show", public_id: "x" }, first_match("/blog/images/x"))
    assert_nil first_match("/teams/blog/abcdefghijkmno", method: "DELETE")
    assert_nil first_match("/teams/blog/images", method: "GET")
    assert_nil first_match("/blog/reviser-le-bepc", method: "POST")
    assert_not helpers.respond_to?(:teams_article_image_path)
  end
end
