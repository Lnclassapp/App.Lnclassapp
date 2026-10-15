require "test_helper"

# Lot D (ADR-0091, UDR-0087) : le texte à trous de bout en bout, sans navigateur. CA-4 : juste sans casse ni espaces en trop,
# faux avec une faute de frappe. CA-9 : aucune réponse acceptée dans la page ni dans le stream. CA-13 : l'équipe le saisit,
# refusé sans `___`. CA-14 : il s'importe.
class Assessment::QuestionFillBlankTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  setup do
    @exercise = create_exercise(title: "Géographie", questions: 0)
    @question = create_kind_question(exercise: @exercise, question_type: "fill_blank", answers: %w[Abidjan Babi],
                                     content: "La capitale économique de la Côte d'Ivoire est ___ .")
    create_kind_question(exercise: @exercise, question_type: "fill_blank", answers: %w[Yamoussoukro], content: "La capitale est ___ .")
    @student = create_student_for(@exercise.essential.course)
    @session = create_exercise_session(student: @student, exercise: @exercise)
  end

  def answer(text) = post(exercise_session_attempts_path(@session.public_id), headers: TURBO,
                                                                              params: { attempt: { question_id: @question.id, response_text: text } })

  test "CA-9 : la page a un champ dans la phrase, nommé par l'énoncé, et aucune réponse acceptée" do
    sign_in_as @student
    get exercise_session_path(@session.public_id)

    assert_select "input[type=text][name='attempt[response_text]'][required][autocapitalize=off][spellcheck=false]" \
                  "[aria-label=?]", "La capitale économique de la Côte d'Ivoire est blanc ."
    assert_no_match(/Abidjan|Babi|Yamoussoukro/, response.body)
  end

  test "CA-4 : « ABIDJAN  » est juste, enregistré tel quel ; le verdict le redit sans rien d'autre" do
    sign_in_as @student
    answer "ABIDJAN  "

    assert_response :success
    assert_equal [ true, "ABIDJAN", [] ], Orm::QuestionAttempt.sole.values_at(:correct, :response_text, :selected_answer_ids)
    assert_select "#feedback-card p[aria-labelledby=feedback-selected]", text: "ABIDJAN"
    assert_no_match(/Abidjan|Babi|Yamoussoukro/, response.body)
  end

  test "CA-4 : une faute de frappe est fausse ; un blanc vide est refusé (422), rien n'est écrit" do
    sign_in_as @student
    answer " "
    assert_response :unprocessable_entity
    assert_equal 0, Orm::QuestionAttempt.count

    answer "Abidjn"
    assert_equal [ false, "Abidjn" ], Orm::QuestionAttempt.sole.values_at(:correct, :response_text)
  end

  test "la correction de l'élève redit son texte ; celle de l'enseignant ajoute les réponses acceptées" do
    Orm::QuestionAttempt.create!(exercise_session: @session, question: @question, correct: false, selected_answer_ids: [],
                                 response_text: "Abidjn", answered_at: Time.current)
    @session.update!(status: "completed", score_percent: 0, completed_at: Time.current)

    sign_in_as @student
    get exercise_session_result_path(@session.public_id)
    assert_select "#question_review_#{@question.id} strong", text: "Abidjn"
    assert_no_match(/Abidjan|Babi/, response.body)

    sign_in_as create_team_member
    get exercise_session_result_path(@session.public_id)
    assert_select "#question_review_#{@question.id} [data-correct]", text: /Abidjan ; Babi/
  end

  test "CA-13 : l'équipe crée un texte à trous ; sans `___`, il est refusé à sa place" do
    essential = create_essential
    sign_in_as create_team_member
    question = ->(content) do
      { exercise: { title: "Trous", exercise_type: "fixation", questions_attributes: {
        "0" => { content:, question_type: "fill_blank", answers_attributes: { "0" => { content: "Abidjan", correct: "1" } } }
      } } }
    end

    post teams_essential_exercises_path(essential.slug), params: question.("Sans blanc."), as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: I18n.t("activemodel.errors.models.dtos/assessment/exercise_input.attributes.questions.blank_marker")

    post teams_essential_exercises_path(essential.slug), params: question.("La capitale est ___ ."), as: :turbo_stream
    assert_equal [ [ "fill_blank", [ [ "Abidjan", true ] ] ] ],
                 Orm::Exercise.find_by!(title: "Trous").questions.map { [ it.question_type, it.answers.pluck(:content, :correct) ] }
  end

  test "le formulaire de l'équipe propose le type et son panneau, caché et désactivé tant qu'un autre type est choisi" do
    sign_in_as create_team_member
    get new_teams_essential_exercise_path(create_essential.slug)

    assert_select "select[name*=question_type] option[value=fill_blank]"
    assert_select "fieldset[data-kind=fill_blank][hidden][disabled]" do
      assert_select "input[type=hidden][name*='[correct]'][value='1']"
    end
  end
end
