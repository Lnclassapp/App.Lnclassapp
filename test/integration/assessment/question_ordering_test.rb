require "test_helper"

# Lot F (ADR-0091 §4.4, UDR-0087) : remettre dans l'ordre de bout en bout, sans navigateur. La page montre les étapes
# mélangées et poste des indices d'affichage, jamais un id (CA-9). Le bon ordre est juste, une étape mal placée est fausse
# (CA-7). « Ton choix » rend l'ordre de l'élève, jamais le bon (CA-10). L'équipe saisit les étapes (CA-13).
class Assessment::QuestionOrderingTest < ActionDispatch::IntegrationTest
  DISTINCT_ANSWER_ID = 914_273_001
  STEPS = %w[Prophase Métaphase Anaphase Télophase].freeze

  setup do
    # Des ids de réponse qu'aucun nombre de la page ne peut valoir (position, « 1 sur 2 », tracé d'icône) : sans cela, un
    # id petit passe pour une fuite, et une vraie fuite d'un id petit passerait pour une position.
    Orm::Answer.connection.execute("ALTER SEQUENCE #{Orm::Answer.sequence_name} RESTART WITH #{DISTINCT_ANSWER_ID}")
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

  # La copie rendue d'un seul envoi (ADR-0112) : cette question seule, l'autre reste vide.
  def answer(contents, order = indices(contents)) = post(exercise_session_copy_path(@session.public_id),
                                                          params: { copy: { answers: { @question.id.to_s => { display_order: order } } } })

  test "CA-9 : les étapes mélangées, des indices d'affichage et des listes de repli ; aucun id d'étape dans la page" do
    get exercise_session_path(@session.public_id)

    ordering = "#question-1 "
    shown = css_select("#{ordering}[data-assessment--ordering-target=item] span.flex-1").map { it.text.strip }
    assert_equal STEPS.sort, shown.sort
    assert_equal %w[0 1 2 3], css_select("#{ordering}[data-assessment--ordering-target=item]").map { it["data-index"] }
    assert_select "#{ordering}select[name='copy[answers][#{@question.id}][display_order][]']", 4
    answer_ids = Orm::Answer.where(question_id: @question.id).pluck(:id).map(&:to_s)
    values = css_select("#copy-form #question-1 [value], #copy-form #question-1 [data-index]").map { it["value"] || it["data-index"] }
    assert_empty answer_ids & (values - [ @question.id.to_s ])
    assert_select "#question-1 button[aria-label=?]", I18n.t("assessment.exercise_sessions.kinds.ordering.up", n: 1)
  end

  test "CA-7 : le bon ordre est juste, enregistré par ids dans l'ordre de l'élève" do
    answer STEPS

    assert_redirected_to exercise_session_result_path(@session.public_id)
    attempt = Orm::QuestionAttempt.find_by!(question: @question)
    assert_equal [ true, @question.answers.order(:position).map(&:id) ], [ attempt.correct, attempt.selected_answer_ids ]
  end

  test "CA-7, CA-10, ADR-0115 D1 : une étape mal placée est fausse ; « Ton choix » rend l'ordre de l'élève, la correction le bon ordre à part" do
    answer %w[Métaphase Prophase Anaphase Télophase]

    assert_equal false, Orm::QuestionAttempt.find_by!(question: @question).correct
    follow_redirect!
    assert_equal %w[Métaphase Prophase Anaphase Télophase],
                 css_select("#question_review_#{@question.id} ol").first.css("li span").map(&:text)
    assert_select "#question_review_#{@question.id} [data-correct] ol li" do |items|
      assert_equal STEPS, items.map { it.css("span").text }
    end
  end

  test "des indices incomplets ou en double sont refusés (422), rien n'est écrit" do
    answer STEPS, [ 0, 0, 1, 2 ]

    assert_response :unprocessable_entity
    assert_equal 0, Orm::QuestionAttempt.count
  end

  test "aucun id de cette question n'apparaît dans la page, où que ce soit" do
    get exercise_session_path(@session.public_id)

    Orm::Answer.where(question_id: @question.id).pluck(:id).each { assert_no_match(/\b#{it}\b/, response.body) }
  end

  test "ADR-0115 D1 : la correction de l'élève (copie vérifiée) marque le bon ordre ; avant la vérification, aucune solution" do
    get exercise_session_result_path(@session.public_id)
    assert_redirected_to exercise_session_path(@session.public_id)
    follow_redirect!
    assert_select "[data-correct]", 0

    answer %w[Métaphase Prophase Anaphase Télophase]
    follow_redirect!
    assert_select "#question_review_#{@question.id} [data-correct]", 1
    assert_select "#question_review_#{@question.id} [data-correct] ol li", STEPS.size
  end
end
