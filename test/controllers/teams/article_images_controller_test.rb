require "test_helper"

# ADR-0073 §4.4, UDR-0065 §3.4.3, BL-08, BL-12 : l'éditeur du blog envoie une image en multipart ; 201 avec exactement
# public_id, sgid, url, width, height ; 422 { error } en français ; 403 { error: "forbidden" } pour qui ne gère pas le blog.
# Un refus ne laisse rien : ni ligne article_images, ni blob dans le bucket.
class Teams::ArticleImagesControllerTest < ActionDispatch::IntegrationTest
  JSON_ACCEPT = { "Accept" => "application/json" }.freeze
  IMAGE = Entities::Communication::ArticleImage

  setup do
    @member = create_team_member(team_role: "content")
  end

  def jpeg = fixture_file_upload("photos/photo.jpg", "image/jpeg")
  def upload(file, **params) = post(teams_article_images_path(**params), params: { article_image: { file: }.compact }, headers: JSON_ACCEPT)
  def json = response.parsed_body

  def bytes_upload(bytes, name)
    Rack::Test::UploadedFile.new(StringIO.new(bytes), "image/jpeg", true, original_filename: name)
  end

  def assert_nothing_stored(&)
    assert_no_difference([ -> { Orm::ArticleImage.count }, -> { ActiveStorage::Blob.count } ], &)
  end

  test "201 : un JPEG d'un membre Contenu répond exactement public_id, sgid, url, width, height ; l'image n'est à aucun article" do
    sign_in_as @member

    assert_difference([ -> { Orm::ArticleImage.count }, -> { ActiveStorage::Blob.count } ], 1) { upload(jpeg) }

    assert_response :created
    assert_equal %w[public_id sgid url width height], json.keys
    image = Orm::ArticleImage.find_by!(public_id: json["public_id"])
    assert_equal [ blog_image_path(image.public_id), 64, 48 ], json.values_at("url", "width", "height")
    assert_equal image, GlobalID::Locator.locate_signed(json["sgid"], for: ActionText::Attachable::LOCATOR_NAME)
    assert_nil image.article_id
    assert_equal [ "image/jpeg", 64, 48 ], [ image.content_type, image.width, image.height ]
  end

  test "l'équipe Administration envoie aussi, un PNG comme un WebP" do
    sign_in_as create_team_member(team_role: "admin")

    upload(fixture_file_upload("photos/photo.png", "image/png"))
    assert_response :created
    upload(fixture_file_upload("photos/photo_lossy.webp", "image/webp"))
    assert_response :created
  end

  test "BL-12 : un GIF, un faux .jpg, 1 Mo + 1 octet, aucun fichier : 422 avec leur raison, table et bucket vides" do
    sign_in_as @member
    oversized = bytes_upload("\xFF\xD8\xFF".b + ("\0".b * (IMAGE::MAX_BYTES - 2)), "lourde.jpg")
    {
      fixture_file_upload("article_images/animation.gif", "image/gif") => "Ce format n'est pas accepté : JPEG, PNG ou WebP fixe seulement.",
      fixture_file_upload("article_images/fake.jpg", "image/jpeg") => "Ce fichier n'est pas une image lisible.",
      oversized => "L'image dépasse 1 Mo, même allégée.",
      nil => "Choisissez une image.",
      "pas un fichier" => "Choisissez une image."
    }.each do |file, message|
      assert_nothing_stored { upload(file) }

      assert_response :unprocessable_entity
      assert_equal({ "error" => message }, json)
    end
    assert_equal 0, Orm::ArticleImage.count
    assert_equal 0, ActiveStorage::Blob.count
  end

  test "BL-08 : le Terrain, l'enseignant, la direction et l'élève reçoivent 403 { error: \"forbidden\" }, rien n'est stocké" do
    [ create_team_member(team_role: "field"), create_teacher, create_school_admin, create_student ].each do |someone|
      sign_in_as someone

      assert_nothing_stored { upload(jpeg) }

      assert_response :forbidden, someone.role
      assert_equal({ "error" => "forbidden" }, json)
      sign_out
    end
  end

  test "un visiteur est renvoyé à la connexion, rien n'est stocké" do
    assert_nothing_stored { upload(jpeg) }

    assert_redirected_to new_session_path
  end

  test "avec un article : la dixième image de son texte passe, la onzième est refusée en 422, un article inconnu en 404" do
    sign_in_as @member
    nine = create_article(status: "draft", body: article_body_with(*Array.new(9) { create_article_image }))
    full = create_article(status: "published", body: article_body_with(*Array.new(10) { create_article_image }))

    upload(jpeg, article: nine.public_id)
    assert_response :created
    assert_nil Orm::ArticleImage.find_by!(public_id: json["public_id"]).article_id

    assert_nothing_stored { upload(jpeg, article: full.public_id) }
    assert_response :unprocessable_entity
    assert_equal({ "error" => "L'article a déjà 10 images dans son texte." }, json)

    assert_nothing_stored { upload(jpeg, article: "inconnu") }
    assert_response :not_found
    assert_equal({ "error" => "not_found" }, json)
  end
end
