require "test_helper"

# Lot D (ADR-0091, UDR-0087) : le texte à trous de bout en bout, sans navigateur. CA-4 : juste sans casse ni espaces en trop,
# faux avec une faute de frappe. CA-9 : aucune réponse acceptée dans la page. CA-13 : l'équipe le saisit,
# refusé sans `___`. CA-14 : il s'importe.
class Assessment::QuestionFillBlankTest < ActionDispatch::IntegrationTest
  setup do
    @exercise = create_exercise(title: "Géographie", questions: 0)
    @question = create_kind_question(exercise: @exercise, question_type: "fill_blank", answers: %w[Abidjan Babi],
                                     content: "La capitale économique de la Côte d'Ivoire est ___ .")
    create_kind_question(exercise: @exercise, question_type: "fill_blank", answers: %w[Yamoussoukro], content: "La capitale est ___ .")
    @student = create_student_for(@exercise.essential.course)
    @session = create_exercise_session(student: @student, exercise: @exercise)
  end

  # La copie rendue d'un seul envoi (ADR-0112) : cette question seule, l'autre reste vide.
  def answer(text) = post(exercise_session_copy_path(@session.public_id),
                          params: { copy: { answers: { @question.id.to_s => { response_text: text } } } })

  test "CA-9 : la page a un champ dans la phrase, nommé par l'énoncé, et aucune réponse acceptée" do
    sign_in_as @student
    get exercise_session_path(@session.public_id)

    assert_select "input[type=text][name='copy[answers][#{@question.id}][response_text]'][autocapitalize=off][spellcheck=false]" \
                  "[aria-label=?]", "La capitale économique de la Côte d'Ivoire est blanc ."
    assert_no_match(/Abidjan|Babi|Yamoussoukro/, response.body)
  end

  test "CA-4, ADR-0115 D1 : « ABIDJAN  » est juste, enregistré tel quel ; la copie vérifiée redit le texte et montre les réponses acceptées ; avant, rien" do
    sign_in_as @student
    # Copie ouverte : pas de correction, et rien des réponses acceptées dans la page où l'on revient.
    get exercise_session_result_path(@session.public_id)
    assert_redirected_to exercise_session_path(@session.public_id)
    follow_redirect!
    assert_no_match(/Abidjan|Babi|Yamoussoukro/, response.body)
    assert_select "[data-correct]", 0

    answer "ABIDJAN  "

    assert_redirected_to exercise_session_result_path(@session.public_id)
    assert_equal [ true, "ABIDJAN", [] ], Orm::QuestionAttempt.find_by!(question: @question).values_at(:correct, :response_text, :selected_answer_ids)
    follow_redirect!
    assert_select "#question_review_#{@question.id} strong", text: "ABIDJAN"
    # ADR-0115 D1 : la copie est vérifiée, les réponses acceptées sont montrées et marquées.
    assert_select "#question_review_#{@question.id} [data-correct]", text: /Abidjan ; Babi/
  end

  test "CA-4 : une faute de frappe est fausse ; un blanc vide est « sans réponse », jamais refusé" do
    sign_in_as @student
    answer " "
    assert_redirected_to exercise_session_result_path(@session.public_id)
    assert_equal [ true, 0 ], [ Orm::QuestionAttempt.find_by!(question: @question).unanswered, Orm::ExerciseSession.find(@session.id).score_percent ]
    assert_response :see_other

    other = create_exercise_session(student: @student, exercise: @exercise)
    post exercise_session_copy_path(other.public_id), params: { copy: { answers: { @question.id.to_s => { response_text: "Abidjn" } } } }
    assert_equal [ false, "Abidjn" ], Orm::QuestionAttempt.find_by!(exercise_session: other, question: @question).values_at(:correct, :response_text)
    follow_redirect!
    # ADR-0115 D1 : la faute est redite, et les réponses acceptées montrées une fois la copie vérifiée.
    assert_select "#question_review_#{@question.id} strong", text: "Abidjn"
    assert_select "#question_review_#{@question.id} [data-correct]", text: /Abidjan ; Babi/
  end

  test "ADR-0115 D1 : la correction de l'élève (copie vérifiée) redit son texte et montre les réponses acceptées, comme celle de l'enseignant ; un autre élève ne la lit pas" do
    Orm::QuestionAttempt.create!(exercise_session: @session, question: @question, correct: false, selected_answer_ids: [],
                                 response_text: "Abidjn", answered_at: Time.current)
    @session.update!(status: "completed", score_percent: 0, completed_at: Time.current)

    sign_in_as @student
    get exercise_session_result_path(@session.public_id)
    assert_select "#question_review_#{@question.id} strong", text: "Abidjn"
    assert_select "#question_review_#{@question.id} [data-correct]", text: /Abidjan ; Babi/

    sign_in_as create_student_for(@exercise.essential.course)
    get exercise_session_result_path(@session.public_id)
    assert_not response.successful?
    assert_no_match(/Abidjan|Babi/, response.body)

    sign_in_as create_team_member
    get exercise_session_result_path(@session.public_id)
    assert_select "#question_review_#{@question.id} [data-correct]", text: /Abidjan ; Babi/
  end
end
