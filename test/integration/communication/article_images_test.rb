require "test_helper"

# ADR-0074 §4.4, BL-14 : /blog/images/:public_id est le seul chemin d'une image du blog. L'image d'un article publié se lit
# sans session, en cache public immuable, sans cookie ; celle d'un brouillon, d'un archivé ou pas encore rattachée se lit
# par qui gère le blog en « private, no-store », et répond 404 à tout autre. La CSP reste celle de toute réponse (ADR-0049).
class Communication::ArticleImagesTest < ActionDispatch::IntegrationTest
  PUBLIC_CACHE = "max-age=31536000, public, immutable"
  PRIVATE_CACHE = "private, no-store"

  setup do
    @cover = create_article_image(fixture: "photos/photo_lossy.webp")
    @body_images = [ create_article_image, create_article_image(fixture: "photos/photo.png") ]
    @published = create_article(cover: @cover, body: article_body_with(*@body_images))
  end

  def bytes(image) = image.file.download

  def assert_served(image, cache:)
    assert_response :success
    assert_equal image.content_type, response.media_type
    assert_equal bytes(image), response.body.b
    assert_equal cache, response.headers["Cache-Control"]
    assert_equal "inline", response.headers["Content-Disposition"].split(";").first
  end

  def outsiders
    [ create_student, create_teacher, create_school_admin, create_team_member(team_role: "field") ]
  end

  test "BL-14 : la couverture et les deux images du texte d'un article publié se lisent sans session, en cache public immuable" do
    [ @cover, *@body_images ].each do |image|
      get blog_image_path(image.public_id)

      assert_served image, cache: PUBLIC_CACHE
      assert_nil response.headers["Set-Cookie"], "une réponse publique et immuable ne pose aucun cookie"
      assert_match(/default-src 'self'/, response.headers["Content-Security-Policy"])
      assert_match(%r{\A/blog/images/[^/]+\z}, blog_image_path(image.public_id))
    end
  end

  test "BL-14 : une personne connectée, de l'équipe comprise, lit aussi l'image publiée en cache public" do
    [ create_student, create_team_member(team_role: "content") ].each do |someone|
      sign_in_as someone

      get blog_image_path(@cover.public_id)

      assert_served @cover, cache: PUBLIC_CACHE
      sign_out
    end
  end

  test "BL-14 : un visiteur, un élève, un enseignant, une direction, le Terrain : 404 sur l'image d'un brouillon, d'un archivé, non rattachée" do
    hidden = hidden_images
    [ nil, *outsiders ].each do |someone|
      sign_in_as someone if someone
      hidden.each_value do |image|
        get blog_image_path(image.public_id)

        assert_response :not_found, "#{someone&.role} #{image.public_id}"
        assert_not_equal bytes(image), response.body.b
        assert_not_includes response.headers["Cache-Control"].to_s, "public"
      end
      sign_out if someone
    end
  end

  test "qui gère le blog lit l'image d'un brouillon, d'un archivé ou non rattachée en « private, no-store »" do
    hidden = hidden_images
    [ create_team_member(team_role: "content"), create_team_member(team_role: "admin") ].each do |member|
      sign_in_as member
      hidden.each_value do |image|
        get blog_image_path(image.public_id)

        assert_served image, cache: PRIVATE_CACHE
      end
      sign_out
    end
  end

  test "un navigateur qui a déjà l'image d'un article publié reçoit 304, sans que le bucket soit lu" do
    get blog_image_path(@cover.public_id)
    etag = response.headers["ETag"]
    assert etag.present?

    downloads = count_downloads { get blog_image_path(@cover.public_id), headers: { "If-None-Match" => etag } }

    assert_response :not_modified
    assert_equal 0, downloads
    assert_empty response.body
    assert_equal [ PUBLIC_CACHE, etag ], response.headers.values_at("Cache-Control", "ETag")
    assert_nil response.headers["Set-Cookie"]
  end

  test "une autre image, ou un ETag périmé, est relue et servie en entier" do
    get blog_image_path(@cover.public_id)
    etag = response.headers["ETag"]

    downloads = count_downloads { get blog_image_path(@body_images.first.public_id), headers: { "If-None-Match" => etag } }

    assert_served @body_images.first, cache: PUBLIC_CACHE
    assert_equal 1, downloads
  end

  test "l'image d'un brouillon, d'un archivé ou non rattachée n'est jamais lue dans le bucket pour qui ne la voit pas, ETag ou non" do
    hidden_images.each_value do |image|
      downloads = count_downloads do
        get blog_image_path(image.public_id)
        get blog_image_path(image.public_id), headers: { "If-None-Match" => "*" }
      end

      assert_response :not_found
      assert_equal 0, downloads, image.public_id
    end
  end

  test "une adresse inconnue répond 404 à tous" do
    get blog_image_path("inconnue")
    assert_response :not_found

    sign_in_as create_team_member(team_role: "content")
    get blog_image_path("inconnue")
    assert_response :not_found
  end

  test "envoyée par un membre Contenu, l'image se lit aussitôt à son adresse en « private, no-store », jamais par Active Storage" do
    sign_in_as create_team_member(team_role: "content")

    post teams_article_images_path, params: { article_image: { file: fixture_file_upload("photos/photo.jpg", "image/jpeg") } },
                                    headers: { "Accept" => "application/json" }
    image = Orm::ArticleImage.find_by!(public_id: response.parsed_body["public_id"])
    assert_not_includes response.body, "/rails/active_storage"

    get response.parsed_body["url"]

    assert_served image, cache: PRIVATE_CACHE
    assert_equal file_fixture("photos/photo.jpg").binread, response.body.b
  end

  private

  def count_downloads(&)
    downloads = 0
    counter = ->(*) { downloads += 1 }
    ActiveSupport::Notifications.subscribed(counter, "service_download.active_storage", &)
    downloads
  end

  def hidden_images
    draft = create_article_image
    archived = create_article_image
    create_article(status: "draft", excerpt: nil, body: article_body_with(draft))
    create_article(status: "archived", body: article_body_with(archived))
    { draft:, archived:, orphan: create_article_image }
  end
end
