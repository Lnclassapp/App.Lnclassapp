require "test_helper"

# Lot E (ADR-0091, UDR-0087) : la réponse en nombre de bout en bout, sans navigateur. CA-5 : la marge s'applique, une saisie
# illisible est une erreur de saisie (422), jamais comptée. CA-6 : le moins Unicode est lu. CA-9 : la valeur attendue n'est
# pas dans la page. CA-13 : l'équipe saisit la valeur et la marge. CA-14 : « tolerance » s'importe.
class Assessment::QuestionNumericTest < ActionDispatch::IntegrationTest
  setup do
    @exercise = create_exercise(title: "Calcul", questions: 0)
    @question = create_kind_question(exercise: @exercise, question_type: "numeric", answers: [ "42,75" ],
                                     numeric_tolerance: BigDecimal("0.25"), content: "Calcule 171 ÷ 4.")
    @negative = create_kind_question(exercise: @exercise, question_type: "numeric", answers: [ "-2" ], content: "Calcule 3 - 5.")
    @student = create_student_for(@exercise.essential.course)
    @session = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student
  end

  def without_svg = response.body.gsub(%r{<svg.*?</svg>}m, "")

  # La copie rendue d'un seul envoi (ADR-0112) : { question => texte }, les autres questions restent vides.
  def copy(texts) = post(exercise_session_copy_path(@session.public_id),
                         params: { copy: { answers: texts.to_h { |question, text| [ question.id.to_s, { response_text: text } ] } } })

  test "CA-9 : un champ décimal et le bouton « ± », sans la valeur attendue ni la marge" do
    get exercise_session_path(@session.public_id)

    assert_select "input[name='copy[answers][#{@question.id}][response_text]'][inputmode=decimal]"
    assert_select "button[aria-label=?]", I18n.t("assessment.exercise_sessions.kinds.numeric.sign"), text: "±"
    # Tout le corps de la page, sauf les icônes : les tracés SVG contiennent des nombres comme 0.25.
    assert_no_match(/42[,.]75|0[,.]25/, without_svg)
  end

  test "CA-5 : « 42.6 » est juste dans la marge ; « 42,,75 » est une erreur de saisie, la question n'est pas comptée" do
    copy @question => "42,,75"
    assert_response :unprocessable_entity
    assert_select "#question-1 fieldset[aria-invalid=true][aria-describedby='question-1-error']"
    assert_select "#question-1-error", text: /\S/
    assert_select "#question-2-error", 0
    assert_select "#copy-errors",
                  text: /#{I18n.t("activemodel.errors.models.dtos/assessment/attempt_input.attributes.response_text.not_a_number")}/
    assert_select "input[name='copy[answers][#{@question.id}][response_text]'][value='42,,75']"
    assert_equal [ 0, "started" ], [ Orm::QuestionAttempt.count, @session.reload.status ]

    copy @question => "42.6"
    assert_equal [ true, "42.6" ], Orm::QuestionAttempt.find_by!(question: @question).values_at(:correct, :response_text)
    follow_redirect!
    assert_select "#question_review_#{@question.id}", text: /42\.6/
  end

  test "ADR-0115 D1 : rien de la valeur ni de la marge avant la vérification ; une mauvaise réponse, une fois la copie vérifiée, montre la valeur et la marge" do
    # Copie refusée (422) : rien n'est écrit, la page ne dit ni la valeur ni la marge.
    copy @question => "42,,75"
    assert_response :unprocessable_entity
    assert_no_match(/42[,.]75|0[,.]25/, without_svg)
    assert_select "[data-correct]", 0
    # Copie ouverte : sa correction n'existe pas encore, on revient à la copie sans la solution.
    get exercise_session_result_path(@session.public_id)
    assert_redirected_to exercise_session_path(@session.public_id)
    follow_redirect!
    assert_no_match(/42[,.]75|0[,.]25/, without_svg)
    assert_select "[data-correct]", 0

    copy @question => "40"
    assert_equal false, Orm::QuestionAttempt.find_by!(question: @question).correct
    follow_redirect!
    assert_select "#question_review_#{@question.id} strong", text: "40"
    assert_select "#question_review_#{@question.id} [data-correct]" do |expected|
      assert_match(/42,75/, expected.text)
      assert_match(/#{Regexp.escape(I18n.t("assessment.exercises.solution.tolerance", tolerance: "0,25"))}/, expected.text)
    end
  end

  test "CA-6 : « −2 » (moins Unicode) est juste" do
    copy @question => "42,75", @negative => "−2"

    assert_equal [ true, true ], Orm::QuestionAttempt.order(:id).pluck(:correct)
  end
end
