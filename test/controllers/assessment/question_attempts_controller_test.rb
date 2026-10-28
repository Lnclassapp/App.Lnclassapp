require "test_helper"

# AS-09, AS-10, AS-11 (UDR-0022) : répondre une fois à une question, voir son verdict et sa progression en Turbo Stream,
# une réponse vide en 422 dans la carte (jamais 500, C-10), une re-soumission refusée sans rien écrire (C-11), la
# dernière réponse qui clôt la session et propose le résultat. La correction ne montre jamais les propositions correctes.
# Lot C (refonte-page-lecon) : l’ancien mode (une question à la fois) n’a plus d’écran ; les tests qui rendaient sa carte
# sont retirés avec lui, ceux qui prouvent les écritures et les refus restent. Suppression du contrôleur : Lot E.
class Assessment::QuestionAttemptsControllerTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze
  ERRORS = "activemodel.errors.models.dtos/assessment/attempt_input.attributes".freeze

  setup do
    @exercise = create_exercise(title: "Méiose", questions: 2)
    # UDR-0013, amendement du 2026-10-01 : la classe de l'élève est du niveau du cours.
    @student = create_student_for(@exercise.essential.course)
    @first, @second = @exercise.questions.order(:position).to_a
    @first.update!(explanation: "La méiose donne quatre cellules.")
    # UDR-0076 §3.3 : le stream joint la question suivante ; ses propositions ont leurs propres textes, pour qu'un test
    # anti-fuite ne confonde jamais une proposition de la question suivante avec la correction de la question tentée.
    @second.update!(content: "La méiose réduit-elle le nombre de chromosomes ?")
    @second.answers.each { it.update!(content: "Choix #{it.position} de la question 2") }
    @session = create_exercise_session(student: @student, exercise: @exercise)
  end

  def scope = "assessment.exercise_sessions"
  def right(question) = question.answers.find_by!(correct: true)
  def wrong(question) = question.answers.where(correct: false).order(:id).first

  def answer(question, *answers, session: @session, headers: TURBO)
    post exercise_session_attempts_path(session.public_id), headers:,
                                                            params: { attempt: { question_id: question.id, answer_ids: answers.map(&:id) } }
  end

  test "la dernière réponse clôt la session dans la même requête : score, badge, lien vers le résultat" do
    create_attempt(session: @session, question: @first, correct: true)
    @session.update!(answered_count: 1, correct_count: 1, progress_percent: 50)
    sign_in_as @student

    answer @second, right(@second)

    @session.reload
    assert_equal [ "completed", 100, 2 ], @session.values_at(:status, :score_percent, :answered_count)
    assert_not_nil @session.completed_at
    assert_equal "diamond", Orm::ExerciseBadge.find_by!(student: @student, exercise: @exercise).level
    assert_select "#feedback-card", text: /#{I18n.t("#{scope}.feedback_card.verdict.success")}/
    assert_select "#feedback-card a[href='#{exercise_session_result_path(@session.public_id)}'][data-turbo-frame=_top]",
                  text: I18n.t("#{scope}.feedback_card.result")
    assert_select "template[data-assessment--next-question-target]", 0
    assert_select "[data-controller='assessment--next-question']", 0
  end

  test "question déjà répondue : rien n'est écrit, toast et retour à l'état de la session" do
    create_attempt(session: @session, question: @first, correct: false)
    sign_in_as @student

    answer @first, right(@first)

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{I18n.t("#{ERRORS}.base.already_answered")}/
    assert_select "turbo-stream[action=refresh]"
    assert_equal [ false ], Orm::QuestionAttempt.pluck(:correct)
  end

  test "session terminée : même refus, sans écriture" do
    @session.update!(status: "completed", score_percent: 0, completed_at: Time.current)
    sign_in_as @student

    answer @first, right(@first)

    assert_select "turbo-stream[action=append][target=toasts]", text: /#{I18n.t("#{ERRORS}.base.session_closed")}/
    assert_equal 0, Orm::QuestionAttempt.count
  end

  test "la session d'un autre élève : 403, rien n'est écrit" do
    sign_in_as create_student

    answer @first, right(@first)

    assert_response :forbidden
    assert_equal 0, Orm::QuestionAttempt.count
  end

  test "un enseignant ne répond pas : 403" do
    sign_in_as create_teacher

    answer @first, right(@first)

    assert_response :forbidden
  end

  test "session inconnue : 404" do
    sign_in_as @student

    post exercise_session_attempts_path("inconnu000000"), headers: TURBO,
                                                          params: { attempt: { question_id: @first.id, answer_ids: [ right(@first).id ] } }

    assert_response :not_found
  end

  test "repli HTML : verdict en flash et retour à la session ; erreur en page complète ; doublon en alerte" do
    sign_in_as @student

    answer @first, right(@first), headers: {}
    assert_redirected_to exercise_session_path(@session.public_id)
    assert_equal I18n.t("assessment.question_attempts.create.success"), flash[:notice]

    answer @second, wrong(@second), headers: {}
    assert_equal I18n.t("assessment.question_attempts.create.error"), flash[:notice]

    answer @first, right(@first), headers: {}
    assert_redirected_to exercise_session_path(@session.public_id)
    assert_equal I18n.t("#{ERRORS}.base.session_closed"), flash[:alert]
  end
end
