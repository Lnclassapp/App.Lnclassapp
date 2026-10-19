require "test_helper"

# ADR-0105 §4.7, UDR-0129 §3.0 : l'éditeur de fiche envoie une image en multipart ; 201 avec exactement public_id, sgid,
# url, width, height ; 422 { error } en français ; 403 pour qui ne gère pas les images ; 401 en JSON sans session.
# Un refus ne laisse rien : ni ligne essential_images, ni blob.
class Teams::EssentialImagesControllerTest < ActionDispatch::IntegrationTest
  JSON_ACCEPT = { "Accept" => "application/json" }.freeze
  CAPS = Entities::Shared::ContentImage

  setup do
    @member = create_team_member(team_role: "content")
  end

  def jpeg = fixture_file_upload("photos/photo.jpg", "image/jpeg")
  def upload(file, **params) = post(teams_essential_images_path(**params), params: { essential_image: { file: }.compact }, headers: JSON_ACCEPT)
  def json = response.parsed_body

  def assert_nothing_stored(&)
    assert_no_difference([ -> { Orm::EssentialImage.count }, -> { ActiveStorage::Blob.count } ], &)
  end

  test "201 : un JPEG d'un membre Contenu répond public_id, sgid, url, width, height ; l'image n'est à aucune fiche" do
    sign_in_as @member

    assert_difference([ -> { Orm::EssentialImage.count }, -> { ActiveStorage::Blob.count } ], 1) { upload(jpeg) }

    assert_response :created
    assert_equal %w[public_id sgid url width height], json.keys
    image = Orm::EssentialImage.find_by!(public_id: json["public_id"])
    assert_equal [ essential_image_path(image.public_id), 64, 48 ], json.values_at("url", "width", "height")
    assert_equal image, GlobalID::Locator.locate_signed(json["sgid"], for: ActionText::Attachable::LOCATOR_NAME)
    assert_nil image.essential_id
  end

  test "422 : un fichier de plus de 300 Ko, un faux .jpg ou aucun fichier, avec leur raison, rien n'est stocké" do
    sign_in_as @member
    heavy = Rack::Test::UploadedFile.new(StringIO.new("\xFF\xD8\xFF".b + ("\0".b * CAPS::MAX_BYTES)), "image/jpeg", true,
                                         original_filename: "lourde.jpg")
    {
      heavy => "L'image dépasse 300 Ko, même allégée.",
      fixture_file_upload("article_images/fake.jpg", "image/jpeg") => "Ce fichier n'est pas une image lisible.",
      nil => "Choisissez une image."
    }.each do |file, message|
      assert_nothing_stored { upload(file) }

      assert_response :unprocessable_entity
      assert_equal({ "error" => message }, json)
    end
    assert_nothing_stored { post teams_essential_images_path, params: { essential_image: "texte" }, headers: JSON_ACCEPT }
    assert_response :unprocessable_entity
  end

  # ADR-0105 §4.1 : le type se lit dans les octets, jamais dans le nom ni dans le type annoncé.
  test "422 : un SVG nommé schema.png et annoncé image/png est refusé sur son vrai format, rien n'est stocké" do
    sign_in_as @member
    svg = Rack::Test::UploadedFile.new(StringIO.new(%(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"></svg>)),
                                       "image/png", true, original_filename: "schema.png")

    assert_nothing_stored { upload(svg) }

    assert_response :unprocessable_entity
    assert_equal({ "error" => "Ce format n'est pas accepté : JPEG, PNG ou WebP fixe seulement." }, json)
  end

  test "201 : un PNG envoyé comme x.jpg en image/jpeg est enregistré pour ce qu'il est, image/png, sous le nom image.png" do
    sign_in_as @member
    png = Rack::Test::UploadedFile.new(file_fixture("photos/photo.png"), "image/jpeg", true, original_filename: "x.jpg")

    assert_difference -> { Orm::EssentialImage.count }, 1 do
      upload(png)
    end

    assert_response :created
    image = Orm::EssentialImage.find_by!(public_id: json["public_id"])
    assert_equal [ "image/png", "image.png" ], [ image.content_type, image.file.filename.to_s ]
    assert_equal "image/png", image.file.blob.content_type
  end

  test "avec une fiche : la 31e image est refusée en 422, une fiche inconnue en 404" do
    sign_in_as @member
    essential = create_essential(status: "draft")
    CAPS::MAX_PER_ESSENTIAL.times { create_essential_image(essential:) }

    assert_nothing_stored { upload(jpeg, essential: essential.slug) }
    assert_response :unprocessable_entity
    assert_equal({ "error" => "30 images au plus par fiche." }, json)

    assert_nothing_stored { upload(jpeg, essential: "inconnue") }
    assert_response :not_found
  end

  test "ADR-0049 : au-delà de 60 envois en une minute, 429 en JSON" do
    sign_in_as @member

    60.times { post teams_essential_images_path, params: { essential_image: { file: "" } }, headers: JSON_ACCEPT }
    post teams_essential_images_path, params: { essential_image: { file: "" } }, headers: JSON_ACCEPT

    assert_response :too_many_requests
    assert_equal({ "error" => I18n.t("errors.codes.rate_limited") }, json)
  end

  test "ADR-0105 : au-delà de 300 envois dans la journée, 429 en JSON" do
    sign_in_as @member
    send_one = -> { post teams_essential_images_path, params: { essential_image: { file: "" } }, headers: JSON_ACCEPT }
    start = Time.current

    # 60 par minute au plus : 5 minutes distinctes d'envois pour atteindre les 300 de la journée.
    5.times do |slot|
      travel_to(start + (slot * 2).minutes) { 60.times { send_one.call } }
    end
    travel_to(start + 12.minutes) do
      send_one.call

      assert_response :too_many_requests
      assert_equal({ "error" => I18n.t("errors.codes.rate_limited_daily") }, json)

      # Le plafond est par compte (menace.md, n° 11) : un second compte Contenu n'est pas limité par les envois du premier.
      sign_out
      sign_in_as create_team_member(team_role: "content")
      send_one.call

      assert_response :unprocessable_entity
      assert_equal({ "error" => "Choisissez une image." }, json)
    end
  end

  test "le Terrain, l'enseignant et l'élève reçoivent 403, rien n'est stocké" do
    [ create_team_member(team_role: "field"), create_teacher, create_student ].each do |someone|
      sign_in_as someone

      assert_nothing_stored { upload(jpeg) }

      assert_response :forbidden, someone.role
      assert_equal({ "error" => "forbidden" }, json)
      sign_out
    end
  end

  test "session expirée : 401 { error } en JSON ; sans JSON, renvoi à la connexion" do
    assert_nothing_stored { upload(jpeg) }
    assert_response :unauthorized
    assert_equal({ "error" => "unauthenticated" }, json)

    post teams_essential_images_path, params: { essential_image: { file: jpeg } }
    assert_redirected_to new_session_path
  end
end
