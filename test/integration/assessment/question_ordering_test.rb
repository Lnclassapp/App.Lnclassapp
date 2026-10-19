require "test_helper"

# Lot F (ADR-0091 §4.4, UDR-0087) : remettre dans l'ordre de bout en bout, sans navigateur. La page montre les étapes
# mélangées et poste des indices d'affichage, jamais un id (CA-9). Le bon ordre est juste, une étape mal placée est fausse
# (CA-7). « Ton choix » rend l'ordre de l'élève, jamais le bon (CA-10). L'équipe saisit les étapes (CA-13).
class Assessment::QuestionOrderingTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze
  STEPS = %w[Prophase Métaphase Anaphase Télophase].freeze

  setup do
    @exercise = create_exercise(title: "Mitose", questions: 0)
    @question = create_kind_question(exercise: @exercise, question_type: "ordering", answers: STEPS, content: "Range les étapes.")
    create_kind_question(exercise: @exercise, question_type: "ordering", answers: %w[Un Deux Trois], content: "Compte.")
    @student = create_student_for(@exercise.essential.course)
    @session = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student
  end

  # Indices d'affichage de chaque étape, dans l'ordre demandé (des contenus).
  def indices(contents)
    ids = @question.answers.order(:position).map(&:id)
    shuffled = Entities::Assessment::AnswerShuffle.for(session_id: @session.id, question_id: @question.id, ids:, avoid: ids)
    contents.map { |content| shuffled.index(ids[STEPS.index(content)]) }
  end

  def answer(contents) = post(exercise_session_attempts_path(@session.public_id), headers: TURBO,
                                                                                   params: { attempt: { question_id: @question.id, display_order: indices(contents) } })

  test "CA-9 : les étapes mélangées, des indices d'affichage et des listes de repli ; aucun id d'étape dans la page" do
    get exercise_session_path(@session.public_id)

    shown = css_select("[data-assessment--ordering-target=item] span.flex-1").map { it.text.strip }
    assert_equal STEPS.sort, shown.sort
    assert_equal %w[0 1 2 3], css_select("[data-assessment--ordering-target=item]").map { it["data-index"] }
    assert_select "select[name='attempt[display_order][]'][required]", 4
    answer_ids = Orm::Answer.where(question_id: @question.id).pluck(:id).map(&:to_s)
    values = css_select("#attempt-form [value], #attempt-form [data-index]").map { it["value"] || it["data-index"] }
    assert_empty answer_ids & (values - [ @question.id.to_s ])
    assert_select "button[aria-label=?]", I18n.t("assessment.exercise_sessions.kinds.ordering.up", n: 1)
  end

  test "CA-7 : le bon ordre est juste, enregistré par ids dans l'ordre de l'élève" do
    answer STEPS

    assert_response :success
    attempt = Orm::QuestionAttempt.sole
    assert_equal [ true, @question.answers.order(:position).map(&:id) ], [ attempt.correct, attempt.selected_answer_ids ]
  end

  test "CA-7, CA-10 : une étape mal placée est fausse ; « Ton choix » rend l'ordre de l'élève et pas le bon" do
    answer %w[Métaphase Prophase Anaphase Télophase]

    assert_equal false, Orm::QuestionAttempt.sole.correct
    assert_select "#feedback-card ol[aria-labelledby=feedback-selected] li" do |items|
      assert_equal %w[Métaphase Prophase Anaphase Télophase], items.map { it.css("span").text }
    end
    assert_select "#feedback-card [data-correct]", 0
  end

  test "des indices incomplets ou en double sont refusés (422), rien n'est écrit" do
    post exercise_session_attempts_path(@session.public_id), headers: TURBO,
                                                             params: { attempt: { question_id: @question.id, display_order: [ 0, 0, 1, 2 ] } }

    assert_response :unprocessable_entity
    assert_equal 0, Orm::QuestionAttempt.count
  end

  test "CA-13 : l'équipe saisit trois étapes dans le bon ordre ; deux sont refusées" do
    essential = create_essential
    sign_in_as create_team_member
    params = ->(steps) do
      { exercise: { title: "Ordre", exercise_type: "fixation", questions_attributes: {
        "0" => { content: "Range.", question_type: "ordering",
                 answers_attributes: steps.each_with_index.to_h { |step, index| [ index.to_s, { content: step, correct: "1" } ] } }
      } } }
    end

    post teams_essential_exercises_path(essential.slug), params: params.(%w[A B]), as: :turbo_stream
    assert_response :unprocessable_entity

    post teams_essential_exercises_path(essential.slug), params: params.(%w[A B C]), as: :turbo_stream
    assert_equal %w[A B C], Orm::Exercise.find_by!(title: "Ordre").questions.sole.answers.order(:position).pluck(:content)
  end


  test "aucun id de cette question n'apparaît dans la page, où que ce soit" do
    get exercise_session_path(@session.public_id)

    Orm::Answer.where(question_id: @question.id).pluck(:id).each { assert_no_match(/\b#{it}\b/, response.body) }
  end

  test "la correction de l'élève ne marque aucune solution" do
    answer %w[Métaphase Prophase Anaphase Télophase]
    student_result_body
    assert_select "[data-correct]", 0
  end

  # La correction de l'élève redit sa réponse, sans aucune solution marquée.
  def student_result_body
    @session.update!(status: "completed", score_percent: 0, completed_at: Time.current)
    sign_in_as @student
    get exercise_session_result_path(@session.public_id)
    response.body
  end
end
