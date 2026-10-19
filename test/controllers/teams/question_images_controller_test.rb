require "test_helper"

# ADR-0105 §4.7, UDR-0129 §3.0 : le formulaire d'exercice envoie l'image d'une question en multipart ; 201 avec exactement
# public_id, url, width, height ; 422 { error } en français ; 403 pour qui n'est pas de l'équipe Administration ou Contenu.
# Un refus ne laisse rien : ni ligne question_images, ni blob.
class Teams::QuestionImagesControllerTest < ActionDispatch::IntegrationTest
  JSON_ACCEPT = { "Accept" => "application/json" }.freeze

  setup { @member = create_team_member(team_role: "content") }

  def jpeg = fixture_file_upload("photos/photo.jpg", "image/jpeg")
  def upload(file) = post(teams_question_images_path, params: { question_image: { file: }.compact }, headers: JSON_ACCEPT)
  def json = response.parsed_body

  def assert_nothing_stored(&)
    assert_no_difference([ -> { Orm::QuestionImage.count }, -> { ActiveStorage::Blob.count } ], &)
  end

  test "201 : un JPEG répond exactement public_id, url, width, height ; l'image n'est à aucune question" do
    sign_in_as @member

    assert_difference([ -> { Orm::QuestionImage.count }, -> { ActiveStorage::Blob.count } ], 1) { upload(jpeg) }

    assert_response :created
    assert_equal %w[public_id url width height], json.keys
    image = Orm::QuestionImage.find_by!(public_id: json["public_id"])
    assert_equal [ question_image_path(image.public_id), 64, 48 ], json.values_at("url", "width", "height")
    assert_nil image.question_id
  end

  test "300 Ko + 1 octet, un faux .jpg, aucun fichier : 422 avec leur raison, rien n'est stocké" do
    sign_in_as @member
    heavy = Rack::Test::UploadedFile.new(StringIO.new("\xFF\xD8\xFF".b + ("\0".b * (Entities::Shared::ContentImage::MAX_BYTES - 2))),
                                         "image/jpeg", true, original_filename: "lourde.jpg")
    {
      heavy => "L'image dépasse 300 Ko, même allégée.",
      fixture_file_upload("article_images/fake.jpg", "image/jpeg") => "Ce fichier n'est pas une image lisible.",
      nil => "Choisissez une image.",
      "pas un fichier" => "Choisissez une image."
    }.each do |file, message|
      assert_nothing_stored { upload(file) }

      assert_response :unprocessable_entity
      assert_equal({ "error" => message }, json)
    end
  end

  test "ADR-0049 : au-delà de 60 envois en une minute, 429 en JSON" do
    sign_in_as @member

    60.times { post teams_question_images_path, params: { question_image: { file: "" } }, headers: JSON_ACCEPT }
    post teams_question_images_path, params: { question_image: { file: "" } }, headers: JSON_ACCEPT

    assert_response :too_many_requests
    assert_equal({ "error" => I18n.t("errors.codes.rate_limited") }, json)
  end

  test "ADR-0105 : au-delà de 300 envois dans la journée, 429 en JSON" do
    sign_in_as @member
    send_one = -> { post teams_question_images_path, params: { question_image: { file: "" } }, headers: JSON_ACCEPT }
    start = Time.current

    # 60 par minute au plus : 5 minutes distinctes d'envois pour atteindre les 300 de la journée.
    5.times do |slot|
      travel_to(start + (slot * 2).minutes) { 60.times { send_one.call } }
    end
    travel_to(start + 12.minutes) do
      send_one.call

      assert_response :too_many_requests
      assert_equal({ "error" => I18n.t("errors.codes.rate_limited_daily") }, json)
    end
  end

  test "le Terrain, l'enseignant et l'élève reçoivent 403, rien n'est stocké" do
    [ create_team_member(team_role: "field"), create_teacher, create_student ].each do |someone|
      sign_in_as someone

      assert_nothing_stored { upload(jpeg) }

      assert_response :forbidden, someone.role
      sign_out
    end
  end

  test "session expirée : 401 { error }, rien n'est stocké" do
    assert_nothing_stored { upload(jpeg) }

    assert_response :unauthorized
    assert_equal({ "error" => "unauthenticated" }, json)
  end
end
