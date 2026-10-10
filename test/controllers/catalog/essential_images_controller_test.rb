require "test_helper"

# ADR-0089 §4.5 : une image de fiche se sert sous la règle de lecture de sa fiche : un élève du niveau la lit si la fiche
# et son cours sont publiés, gardée par son seul navigateur (privé, immuable) ; brouillon, hors niveau ou remplacée : 404 ;
# sans connexion : jamais.
class Catalog::EssentialImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(level: create_level(name: "6ème"))
    @essential = create_essential(course: @course)
    @image = create_essential_image(essential: @essential, alt: "Une pile", fixture: "photos/photo.png")
    @student = create_student_for(@course)
  end

  test "l'élève du niveau lit l'image d'une fiche publiée, en cache privé immuable, et 304 ensuite sans relire le fichier" do
    sign_in_as @student
    get essential_image_path(@image.public_id) # consomme l'avis de connexion, qui entre dans l'ETag (EtagWithFlash)

    get essential_image_path(@image.public_id)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert response.body.b == file_fixture("photos/photo.png").binread, "octets servis : #{response.body.bytesize}"
    assert_equal "max-age=31536000, private, immutable", response.headers["Cache-Control"]
    etag = response.headers["ETag"]

    get essential_image_path(@image.public_id), headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end

  test "brouillon : 404 pour l'élève ; l'équipe la lit, jamais gardée" do
    @essential.update!(status: "draft", published_at: nil)
    sign_in_as @student
    get essential_image_path(@image.public_id)
    assert_response :not_found
    sign_out

    sign_in_as create_team_member(team_role: "content")
    get essential_image_path(@image.public_id)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "un élève d'un autre niveau reçoit 404" do
    other = create_course(level: create_level(name: "3ème"))
    sign_in_as create_student_for(other)

    get essential_image_path(@image.public_id)

    assert_response :not_found
  end

  test "une image remplacée (supprimée) ou inconnue répond 404" do
    sign_in_as @student
    public_id = @image.public_id
    @image.destroy!

    get essential_image_path(public_id)
    assert_response :not_found
    get essential_image_path("inconnu0000000")
    assert_response :not_found
  end

  test "sans connexion, l'image n'est pas servie" do
    get essential_image_path(@image.public_id)

    assert_redirected_to new_session_path
    assert_not_equal "image/png", response.media_type
  end
end
