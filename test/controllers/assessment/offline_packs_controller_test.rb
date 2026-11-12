require "test_helper"

# CA-5 — hors-connexion Lot B (ADR §4.4, menace C2) : le paquet de corrigé n'est servi qu'à l'élève qui peut démarrer l'exercice.
class Assessment::OfflinePacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    course = create_course(level: create_level(name: "Tle"), series: create_series(name: "D"), material: create_material(name: "SVT", category: "science"))
    @exercise = create_exercise(essential: create_essential(course:), questions: 2)
    @student = create_student_for(course)
  end

  test "l'élève reçoit les questions avec bonnes réponses, l'empreinte et un jeton signé, en no-store" do
    sign_in_as @student

    get offline_pack_exercise_path(@exercise.public_id)

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match(/no-store/, response.headers["Cache-Control"])
    body = response.parsed_body
    assert_equal @exercise.public_id, body["exercise_public_id"]
    assert_equal 2, body["questions"].size
    assert_equal [ true, false, false, false ], body["questions"].first["answers"].pluck("correct")
    assert_match(/\A\h{16}\z/, body["digest"])
    verified = Repositories::Assessment::OfflinePackSigner.new.verify(body["token"])
    assert_equal({ student_id: @student.id, exercise_id: @exercise.id, digest: body["digest"] }, verified.slice(:student_id, :exercise_id, :digest))
    assert_in_delta Time.current, verified[:issued_at], 5.seconds
    assert_equal verified[:issued_at].iso8601, body["issued_at"]
  end

  test "exercice assigné en devoir en attente : le paquet est servi et la remise est enregistrée (menace C1, décision du porteur)" do
    create_assignment(classroom: Orm::ClassroomStudent.find_by(student: @student, primary: true).classroom, assignable: @exercise)
    sign_in_as @student

    assert_no_difference -> { Orm::ExerciseSession.count } do
      get offline_pack_exercise_path(@exercise.public_id)
    end

    assert_response :success
    assert_equal 2, response.parsed_body["questions"].size
    delivery = Orm::OfflinePackDelivery.find_by!(student_id: @student.id, exercise_id: @exercise.id)
    assert_in_delta Time.current, delivery.first_delivered_at, 5.seconds
  end

  test "un second appel avance la dernière remise et garde la première" do
    sign_in_as @student
    travel_to Time.utc(2026, 11, 12, 8, 0, 0) do
      get offline_pack_exercise_path(@exercise.public_id)
    end
    travel_to Time.utc(2026, 11, 13, 8, 0, 0) do
      get offline_pack_exercise_path(@exercise.public_id)
    end

    delivery = Orm::OfflinePackDelivery.find_by!(student_id: @student.id, exercise_id: @exercise.id)
    assert_equal [ Time.utc(2026, 11, 12, 8), Time.utc(2026, 11, 13, 8) ], [ delivery.first_delivered_at, delivery.last_delivered_at ]
  end

  test "un refus n'enregistre aucune remise" do
    sign_in_as create_teacher
    get offline_pack_exercise_path(@exercise.public_id)

    assert_response :forbidden
    assert_equal 0, Orm::OfflinePackDelivery.count
  end

  test "remise impossible à écrire : 503, le corrigé n'est pas servi sans trace, l'erreur est signalée" do
    sign_in_as @student
    reported = []
    subscriber = Class.new { define_method(:report) { |error, **| reported << error } }.new
    Rails.error.subscribe(subscriber)
    failing = ->(**) { raise ActiveRecord::StatementInvalid, "boom" }
    stub_any_instance(Repositories::Assessment::OfflinePackDeliveryRepository, :record, failing) do
      get offline_pack_exercise_path(@exercise.public_id)
    end

    assert_response :service_unavailable
    assert_no_match(/"answers"/, response.body)
    assert_equal 1, reported.size
  ensure
    Rails.error.unsubscribe(subscriber) if subscriber
  end

  test "le devoir une fois rendu, le paquet est servi" do
    classroom = Orm::ClassroomStudent.find_by(student: @student, primary: true).classroom
    assignment = create_assignment(classroom:, assignable: @exercise)
    create_exercise_session(student: @student, exercise: @exercise, status: "completed", classroom_assignment_id: assignment.id)
    sign_in_as @student

    get offline_pack_exercise_path(@exercise.public_id)

    assert_response :success
  end

  test "aucun Orm::Answer.id dans le JSON : des rangs locaux" do
    sign_in_as @student

    get offline_pack_exercise_path(@exercise.public_id)

    body = response.parsed_body
    assert(body["questions"].all? { |question| question["answers"].none? { it.key?("id") } })
    assert_equal [ 0, 1, 2, 3 ].sort, body["questions"].first["display"].sort
  end

  test "servir le paquet n'écrit rien" do
    sign_in_as @student

    assert_no_difference -> { Orm::ExerciseSession.count } do
      get offline_pack_exercise_path(@exercise.public_id)
    end
  end

  test "un visiteur non connecté est refusé" do
    get offline_pack_exercise_path(@exercise.public_id)

    assert_not response.successful?
    assert_no_match(/"answers"/, response.body)
  end

  test "un enseignant est refusé" do
    sign_in_as create_teacher

    get offline_pack_exercise_path(@exercise.public_id)

    assert_response :forbidden
    assert_no_match(/"answers"/, response.body)
  end

  test "un élève d'un autre niveau est refusé" do
    other = create_student_for(create_course(level: create_level(name: "6e"), series: create_series(name: "A"), material: create_material(name: "Maths", category: "science")))
    sign_in_as other

    get offline_pack_exercise_path(@exercise.public_id)

    assert_response :not_found
    assert_no_match(/"answers"/, response.body)
  end

  test "un exercice non publié est refusé" do
    @exercise.update!(status: "draft")
    sign_in_as @student

    get offline_pack_exercise_path(@exercise.public_id)

    assert_response :not_found
  end

  test "un exercice inconnu est refusé" do
    sign_in_as @student

    get offline_pack_exercise_path("inconnu")

    assert_response :not_found
  end

  test "un élève dont l'accès est bloqué est refusé" do
    close_beta_for_this_test
    sign_in_as @student
    travel_to 30.days.from_now do
      sign_in_as @student
      get offline_pack_exercise_path(@exercise.public_id)
    end

    assert_response :payment_required
    assert_no_match(/"answers"/, response.body)
  end

  test "au-delà de 30 demandes par minute, la suivante est refusée" do
    sign_in_as @student
    30.times { get offline_pack_exercise_path(@exercise.public_id) }
    assert_response :success

    get offline_pack_exercise_path(@exercise.public_id)

    assert_response :too_many_requests
  end
end
