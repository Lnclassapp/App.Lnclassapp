require "test_helper"

# Lot E (ADR-0091, UDR-0087) : la réponse en nombre de bout en bout, sans navigateur. CA-5 : la marge s'applique, une saisie
# illisible est une erreur de saisie (422), jamais comptée. CA-6 : le moins Unicode est lu. CA-9 : la valeur attendue n'est
# pas dans la page. CA-13 : l'équipe saisit la valeur et la marge. CA-14 : « tolerance » s'importe.
class Assessment::QuestionNumericTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  setup do
    @exercise = create_exercise(title: "Calcul", questions: 0)
    @question = create_kind_question(exercise: @exercise, question_type: "numeric", answers: [ "42,75" ],
                                     numeric_tolerance: BigDecimal("0.25"), content: "Calcule 171 ÷ 4.")
    @negative = create_kind_question(exercise: @exercise, question_type: "numeric", answers: [ "-2" ], content: "Calcule 3 - 5.")
    @student = create_student_for(@exercise.essential.course)
    @session = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student
  end

  def answer(question, text) = post(exercise_session_attempts_path(@session.public_id), headers: TURBO,
                                                                                         params: { attempt: { question_id: question.id, response_text: text } })

  test "CA-9 : un champ décimal et le bouton « ± », sans la valeur attendue ni la marge" do
    get exercise_session_path(@session.public_id)

    assert_select "input[name='attempt[response_text]'][inputmode=decimal][required]"
    assert_select "button[aria-label=?]", I18n.t("assessment.exercise_sessions.kinds.numeric.sign"), text: "±"
    assert_no_match(/42[,.]75|0[,.]25/, response.body)
  end

  test "CA-5 : « 42.6 » est juste dans la marge ; « 42,,75 » est une erreur de saisie, la question n'est pas comptée" do
    answer @question, "42,,75"
    assert_response :unprocessable_entity
    assert_select "turbo-stream[target=question] #attempt-errors",
                  text: I18n.t("activemodel.errors.models.dtos/assessment/attempt_input.attributes.response_text.not_a_number")
    assert_equal [ 0, 0 ], [ Orm::QuestionAttempt.count, @session.reload.answered_count ]

    answer @question, "42.6"
    assert_equal [ true, "42.6" ], Orm::QuestionAttempt.sole.values_at(:correct, :response_text)
    assert_select "#feedback-card p[aria-labelledby=feedback-selected]", text: "42.6"
  end

  test "une mauvaise réponse ne révèle ni la valeur ni la marge, au verdict comme au résultat" do
    answer @question, "40"
    assert_equal false, Orm::QuestionAttempt.sole.correct
    assert_no_match(/42[,.]75|0[,.]25/, response.body)

    student_result_body
    # Le texte de la page, pas ses icônes : les tracés SVG contiennent des nombres comme 0.25.
    assert_no_match(/42[,.]75|0[,.]25/, css_select("main").text)
    assert_select "[data-correct]", 0
  end

  # La correction de l'élève redit sa réponse, sans aucune solution marquée.
  def student_result_body
    @session.update!(status: "completed", score_percent: 0, completed_at: Time.current)
    sign_in_as @student
    get exercise_session_result_path(@session.public_id)
    response.body
  end


  test "CA-6 : « −2 » (moins Unicode) est juste" do
    answer @question, "42,75"
    answer @negative, "−2"

    assert_equal [ true, true ], Orm::QuestionAttempt.order(:id).pluck(:correct)
  end

  test "CA-13 : l'équipe saisit la valeur et la marge ; une marge illisible est refusée à sa place" do
    essential = create_essential
    sign_in_as create_team_member
    params = ->(tolerance) do
      { exercise: { title: "Nombre", exercise_type: "fixation", questions_attributes: {
        "0" => { content: "Combien ?", question_type: "numeric", numeric_tolerance: tolerance,
                 answers_attributes: { "0" => { content: "-3,5", correct: "1" } } }
      } } }
    end

    post teams_essential_exercises_path(essential.slug), params: params.("beaucoup"), as: :turbo_stream
    assert_response :unprocessable_entity
    # Trop grande pour decimal(12,4) : refusée comme règle de structure, sans erreur de la base.
    post teams_essential_exercises_path(essential.slug), params: params.("1000000000"), as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: I18n.t("activemodel.errors.models.dtos/assessment/exercise_input.attributes.questions.tolerance_out_of_range")
    assert_equal 0, Orm::Exercise.where(title: "Nombre").count

    post teams_essential_exercises_path(essential.slug), params: params.("0,25"), as: :turbo_stream
    question = Orm::Exercise.find_by!(title: "Nombre").questions.sole
    assert_equal [ "numeric", BigDecimal("0.25"), [ "-3,5" ] ], [ question.question_type, question.numeric_tolerance, question.answers.pluck(:content) ]
  end
end
