require "test_helper"

# hors-connexion, Lot C (CA-8, CA-9, menace R2, R3, R5, R7) : l'envoi des copies en file. JSON, élève seulement, CSRF normal,
# 20 copies, 256 Kio (413), 30 par minute ; une réponse par copie, jamais d'échec global pour une copie refusée.
class Assessment::OfflineCopySyncsControllerTest < ActionDispatch::IntegrationTest
  UUIDS = Array.new(21) { |index| format("3f2b8a1e-5c4d-4e6f-9a7b-1c2d3e4f%04x", index) }.freeze

  setup do
    @exercise = create_exercise(questions: 2)
    @student = create_student_for(@exercise.course)
    @first, @second = @exercise.questions.order(:position).to_a
    @signer = Repositories::Assessment::OfflinePackSigner.new
    @now = Time.current
  end

  def right(question) = question.answers.find_by!(correct: true).id

  # Les indices d'affichage du paquet : mélange à la graine de l'identifiant de l'exercice.
  def shown(question, id)
    order = Entities::Assessment::AnswerShuffle.for(session_id: @exercise.id, question_id: question.id, ids: question.answers.pluck(:id))
    [ order.index(id).to_s ]
  end

  def digest = UseCases::Assessment::SyncOfflineCopy.digest_for(Repositories::Assessment::ExerciseRepository.new.find(id: @exercise.id))

  def token(student: @student)
    @signer.sign(student_id: student.id, exercise_id: @exercise.id, digest:, issued_at: @now - 3600)
  end

  def copy(index = 0, **overrides)
    { client_copy_id: UUIDS[index], exercise_public_id: @exercise.public_id, pack_token: token, started_at: (@now - 600).iso8601,
      submitted_at: (@now - 60).iso8601, answers: { @first.id.to_s => { display_order: shown(@first, right(@first)) } } }.merge(overrides)
  end

  def send_copies(*copies) = post(offline_copies_path, params: { copies: }, as: :json)

  def results = response.parsed_body.fetch("results")

  test "une copie valide est enregistrée : synced, la note du serveur et le lien du résultat" do
    sign_in_as @student

    send_copies copy(provisional_percent: 100)

    assert_response :ok
    row = Orm::ExerciseSession.find_by!(client_copy_id: UUIDS[0])
    assert_equal [ { "client_copy_id" => UUIDS[0], "status" => "synced", "percent" => 50, "url" => exercise_session_result_path(row.public_id) } ], results
    assert_equal 50, row.score_percent
  end

  test "le même envoi deux fois : already_synced, une seule copie" do
    sign_in_as @student
    send_copies copy

    assert_no_difference "Orm::ExerciseSession.count" do
      send_copies copy
    end

    assert_equal [ "already_synced", 50 ], results.first.values_at("status", "percent")
  end

  test "une copie refusée est rendue rejected avec son motif, les autres passent" do
    sign_in_as @student
    other = create_student_for(@exercise.course)

    send_copies copy(0, pack_token: token(student: other)), copy(1), copy(2, client_copy_id: "pas-un-uuid")

    assert_equal [ [ "rejected", "wrong_owner" ], [ "synced", nil ], [ "rejected", "invalid" ] ], results.map { it.values_at("status", "reason") }
    assert_equal 1, Orm::ExerciseSession.where(student: @student).count
  end

  test "un exercice modifié depuis l'émission du paquet donne le motif stale" do
    sign_in_as @student
    stale = token
    @first.answers.first.update!(content: "Modifié")

    send_copies copy(pack_token: stale)

    assert_equal [ "rejected", "stale" ], results.first.values_at("status", "reason")
  end

  test "plus de 20 copies : 422, rien n'est écrit" do
    sign_in_as @student

    assert_no_difference "Orm::ExerciseSession.count" do
      send_copies(*Array.new(21) { copy(it) })
    end

    assert_response :unprocessable_entity
  end

  test "un corps de plus de 256 Kio : 413, rien n'est écrit" do
    sign_in_as @student

    assert_no_difference "Orm::ExerciseSession.count" do
      send_copies copy(answers: { @first.id.to_s => { response_text: "x" * (300 * 1024) } })
    end

    assert_response :content_too_large
  end

  test "un corps qui n'est pas une liste de copies : 422" do
    sign_in_as @student

    post offline_copies_path, params: { copies: "texte" }, as: :json
    assert_response :unprocessable_entity

    post offline_copies_path, params: { copies: [ "texte" ] }, as: :json
    assert_response :unprocessable_entity
  end

  test "la note envoyée par le client n'est pas lue" do
    sign_in_as @student

    send_copies copy(score: 100, score_percent: 100, provisional_percent: 100)

    assert_equal 50, Orm::ExerciseSession.find_by!(client_copy_id: UUIDS[0]).score_percent
  end

  test "un enseignant : 403 ; sans connexion : rien n'est écrit" do
    sign_in_as create_teacher

    assert_no_difference "Orm::ExerciseSession.count" do
      send_copies copy
    end

    assert_response :forbidden
  end

  test "sans connexion : redirigé, rien n'est écrit" do
    assert_no_difference "Orm::ExerciseSession.count" do
      send_copies copy
    end

    assert_response :redirect
  end

  test "31e envoi dans la minute : 429, rien n'est écrit" do
    sign_in_as @student
    30.times { send_copies copy(0, client_copy_id: "x") }
    assert_response :ok

    assert_no_difference "Orm::ExerciseSession.count" do
      send_copies copy
    end

    assert_response :too_many_requests
  end

  test "R7 : sans jeton CSRF la protection de Rails refuse l'envoi ; avec le jeton de la page il passe" do
    sign_in_as @student
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    assert_no_difference "Orm::ExerciseSession.count" do
      send_copies copy
    end
    assert_response :unprocessable_entity

    get student_home_path
    csrf = css_select('meta[name="csrf-token"]').first["content"]
    post offline_copies_path, params: { copies: [ copy ] }, as: :json, headers: { "X-CSRF-Token" => csrf }

    assert_response :ok
    assert_equal "synced", results.first["status"]
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
