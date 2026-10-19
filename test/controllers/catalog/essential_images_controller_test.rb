require "test_helper"

# ADR-0105 §4.5 : une image de fiche se sert sous la règle de lecture de sa fiche : un élève du niveau la lit si la fiche
# et son cours sont publiés, gardée une heure par son seul navigateur puis revalidée ; brouillon, hors niveau ou remplacée : 404 ;
# sans connexion : jamais.
class Catalog::EssentialImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(level: create_level(name: "6ème"))
    @essential = create_essential(course: @course)
    @image = create_essential_image(essential: @essential, alt: "Une pile", fixture: "photos/photo.png")
    @student = create_student_for(@course)
  end

  test "l'élève du niveau lit l'image d'une fiche publiée, en cache privé d'une heure, et 304 ensuite sans relire le fichier" do
    sign_in_as @student
    get essential_image_path(@image.public_id) # consomme l'avis de connexion, qui entre dans l'ETag (EtagWithFlash)

    get essential_image_path(@image.public_id)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert response.body.b == file_fixture("photos/photo.png").binread, "octets servis : #{response.body.bytesize}"
    assert_equal "max-age=3600, private", response.headers["Cache-Control"]
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
  end

  # PRD §2 : un enseignant lit l'image d'une fiche comme la fiche elle-même (ReadsOwnLevel ne borne que l'élève).
  test "un enseignant reçoit pour l'image la même réponse que pour sa fiche ; archivée, 404 comme elle" do
    sign_in_as create_teacher(material: @course.material)

    get course_essential_path(@course.slug, @essential.slug)
    page_status = response.status
    get essential_image_path(@image.public_id)
    assert_equal [ 200, 200 ], [ page_status, response.status ]

    @essential.update!(status: "archived", archived_at: Time.current)
    get course_essential_path(@course.slug, @essential.slug)
    page_status = response.status
    get essential_image_path(@image.public_id)
    assert_equal [ 404, 404 ], [ page_status, response.status ]
  end

  test "une ligne sans son fichier répond 404 et le journal le dit, au lieu d'une image vide" do
    @image.file.purge
    sign_in_as @student

    logs = capture_log { get essential_image_path(@image.public_id) }

    assert_response :not_found
    assert_includes logs, "[Catalog::EssentialImagesController] fichier absent public_id=#{@image.public_id}"
  end

  # Le bucket a perdu le fichier alors que la ligne du blob existe : Active Storage lève FileNotFoundError, qui ne doit pas être un 500.
  test "une ligne dont le blob existe mais pas le fichier dans le bucket répond 404 et le journal le dit" do
    blob = @image.file.blob
    blob.service.delete(blob.key)
    sign_in_as @student

    logs = capture_log { get essential_image_path(@image.public_id) }

    assert_response :not_found
    assert_includes logs, "[Catalog::EssentialImagesController] fichier absent public_id=#{@image.public_id}"
  end
end
