require "test_helper"

# ADR-0105 §4.5 : l'image d'une question se sert sous la règle de lecture de son exercice. Publiée : en cache navigateur
# privé d'une heure, puis revalidée : 304 sur son ETag. Brouillon ou non rattachée : l'équipe seule, jamais gardée. Un élève hors du
# niveau, ou un brouillon pour l'élève : 404. Sans connexion : pas d'image.
class Assessment::QuestionImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course
    @exercise = create_exercise(essential: create_essential(course: @course))
    @image = create_question_image(question: @exercise.questions.first, alt: "Une pile", fixture: "photos/photo.png")
    @student = create_student_for(@course)
  end

  def fetch(image = @image, headers: {}) = get(question_image_path(image.public_id), headers:)

  test "l'élève du niveau reçoit l'image publiée, en cache privé d'une heure ; 304 sur son ETag" do
    sign_in_as @student

    fetch

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal Digest::SHA256.hexdigest(@image.file.download), Digest::SHA256.hexdigest(response.body)
    assert_equal "max-age=3600, private", response.headers["Cache-Control"]
    fetch # la connexion a laissé un message flash, que Rails mêle à l'ETag : la première image lue le consomme
    fetch(headers: { "If-None-Match" => response.headers["ETag"] })
    assert_response :not_modified
  end

  test "brouillon : 404 pour l'élève ; l'équipe la lit sans cache" do
    @exercise.update!(status: "draft", published_at: nil)
    sign_in_as @student
    fetch
    assert_response :not_found
    sign_out

    sign_in_as create_team_member(team_role: "content")
    fetch
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "un élève d'un autre niveau : 404 ; une image non rattachée : 404 pour l'élève" do
    sign_in_as create_student_for(create_course)
    fetch
    assert_response :not_found
    sign_out

    sign_in_as @student
    fetch(create_question_image)
    assert_response :not_found
  end

  test "sans connexion, l'image n'est pas servie" do
    fetch

    assert_redirected_to new_session_path
  end

  test "exercice archivé : 404 pour l'élève du niveau" do
    @exercise.update!(status: "archived", archived_at: Time.current)
    sign_in_as @student

    fetch

    assert_response :not_found
  end

  # PRD §2 : un enseignant lit l'image d'une question comme son exercice (ReadsOwnLevel ne borne que l'élève).
  test "un enseignant reçoit pour l'image la même réponse que pour son exercice ; archivé, 404 comme lui" do
    sign_in_as create_teacher(material: @course.material)

    get exercise_path(@exercise.public_id)
    page_status = response.status
    fetch
    assert_equal [ 200, 200 ], [ page_status, response.status ]

    @exercise.update!(status: "archived", archived_at: Time.current)
    get exercise_path(@exercise.public_id)
    page_status = response.status
    fetch
    assert_equal [ 404, 404 ], [ page_status, response.status ]
  end

  test "une ligne sans son fichier répond 404 et le journal le dit, au lieu d'une image vide" do
    @image.file.purge
    sign_in_as @student

    logs = capture_log { fetch }

    assert_response :not_found
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_nil response.headers["ETag"]
    assert_includes logs, "[Assessment::QuestionImagesController] fichier absent public_id=#{@image.public_id}"
  end

  # Le bucket a perdu le fichier alors que la ligne du blob existe : Active Storage lève FileNotFoundError, qui ne doit pas être un 500.
  test "une ligne dont le blob existe mais pas le fichier dans le bucket répond 404 et le journal le dit" do
    blob = @image.file.blob
    blob.service.delete(blob.key)
    sign_in_as @student

    logs = capture_log { fetch }

    assert_response :not_found
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_nil response.headers["ETag"]
    assert_includes logs, "[Assessment::QuestionImagesController] fichier absent public_id=#{@image.public_id}"
  end
end
