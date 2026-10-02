require "test_helper"

# AS-11, AS-12, AS-13, AS-39 (UDR-0023) : le résultat d'une session terminée — note sur 20, score, maîtrise, badge,
# « Félicitations ! » et confettis dès le seuil de réussite, « Courage ! » en dessous, « Recommencer » sous 100.
# L'élève propriétaire y voit ses choix, le verdict et l'explication, jamais les propositions correctes (décision du
# porteur, 881a623) ; l'enseignant d'une classe active de l'élève et l'équipe voient la correction complète.
class Assessment::SessionResultsControllerTest < ActionDispatch::IntegrationTest
  GRADING = Entities::Assessment::Grading

  setup do
    @essential = create_essential(name: "Division cellulaire")
    # UDR-0013, amendement du 2026-10-01 : la classe de l'élève est du niveau du cours.
    @classroom = create_classroom(level: @essential.course.level)
    @student = create_student(classroom: @classroom, first_name: "Mariam", last_name: "Traoré")
    @exercise = create_exercise(essential: @essential, title: "Méiose", questions: 2)
    @first, @second = @exercise.questions.order(:position).to_a
    @first.update!(content: "Combien de cellules donne la méiose ?", explanation: "Quatre cellules filles.")
    [ @first, @second ].each_with_index do |question, rank|
      question.answers.order(:position).each_with_index { |answer, index| answer.update!(content: "Choix #{rank + 1}.#{index + 1}") }
    end
    @session = complete(score_percent: GRADING::PASS_THRESHOLD, first_correct: false)
  end

  def scope = "assessment.session_results"
  def right(question) = question.answers.find_by!(correct: true)
  def wrong(question) = question.answers.where(correct: false).order(:id).first

  def complete(score_percent:, first_correct: true, student: @student)
    create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent:).tap do |session|
      create_attempt(session:, question: @first, correct: first_correct)
      create_attempt(session:, question: @second, correct: true)
    end
  end

  def show(session = @session) = get(exercise_session_result_path(session.public_id))

  test "l'élève voit sa note, son score, sa maîtrise, son badge, « Félicitations ! » et les confettis" do
    sign_in_as @student

    show

    assert_response :success
    assert_select "title", text: /Méiose/
    assert_select "h1", text: I18n.t("#{scope}.show.headline.success")
    assert_select "[data-controller='assessment--confetti']", 1
    assert_select "#session_result", text: /10\/20/
    assert_select "#session_result", text: /#{GRADING::PASS_THRESHOLD} %/
    assert_select "#session_result", text: /#{I18n.t("assessment.badges.mastery.fragile")}/
    assert_select "#session_badge[aria-label=?]", I18n.t("#{scope}.badge.label", level: "Bronze")
    assert_select "#session_badge", text: /#{I18n.t("#{scope}.badge.new")}/, count: 0
    assert_select "a[href='#{course_essential_path(@essential.course.slug, @essential.slug)}']", text: /Division cellulaire/
    assert_select "form[method=post][action='#{exercise_sessions_path(@exercise.public_id)}']" do
      assert_select "button[type=submit]", text: I18n.t("#{scope}.show.restart")
    end
  end

  test "la revue de l'élève : ses choix, le verdict et l'explication, jamais une proposition juste qu'il n'a pas choisie" do
    sign_in_as @student

    show

    assert_select "#question_review_#{@first.id}" do
      assert_select "*", text: /#{I18n.t("#{scope}.question_review.verdict.error")}/
      assert_select "*", text: /Combien de cellules donne la méiose \?/
      assert_select "*", text: /Quatre cellules filles\./
      assert_select "li", text: wrong(@first).content, count: 1
    end
    assert_select "#question_review_#{@second.id}", text: /#{I18n.t("#{scope}.question_review.verdict.success")}/
    assert_no_match right(@first).content, response.body
    assert_no_match(/#{I18n.t("#{scope}.question_review.correct")}|data-correct/, response.body)
    assert_select "#question_review_#{@first.id} li", 1
  end

  test "l'enseignant d'une classe active de l'élève voit la correction complète, propositions correctes marquées" do
    teacher = create_teacher(classrooms: [ @classroom ])
    sign_in_as teacher

    show

    assert_response :success
    assert_select "#session_result", text: /Mariam Traoré/
    assert_select "#question_review_#{@first.id} li", 4
    assert_select "#question_review_#{@first.id} li[data-correct]", text: /#{right(@first).content}/, count: 1
    assert_select "#question_review_#{@first.id} li[data-selected]", text: /#{wrong(@first).content}/, count: 1
    assert_select "#question_review_#{@first.id}", text: /#{I18n.t("#{scope}.question_review.correct")}/
    assert_select "form[action='#{exercise_sessions_path(@exercise.public_id)}']", 0
  end

  test "l'équipe voit le résultat et la correction complète" do
    sign_in_as create_team_member

    show

    assert_response :success
    assert_select "li[data-correct]", 2
  end

  test "un autre élève, ou un enseignant qui n'enseigne pas à l'élève : 403, sans rien montrer" do
    [ create_student(classroom: @classroom), create_teacher(classrooms: [ create_classroom ]) ].each do |intruder|
      sign_in_as intruder

      show

      assert_response :forbidden
      assert_no_match(/Méiose|Choix 1/, response.body)
      sign_out
    end
  end

  test "session inconnue : 404" do
    sign_in_as @student

    get exercise_session_result_path("inconnue")

    assert_response :not_found
  end

  test "session non terminée : retour à la session" do
    started = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student

    show started

    assert_redirected_to exercise_session_path(started.public_id)
  end

  test "sous le seuil de réussite : « Courage ! », « En difficulté », « Non acquis », aucun confetti, « Recommencer »" do
    failed = complete(score_percent: GRADING::PASS_THRESHOLD - 10, first_correct: false)
    sign_in_as @student

    show failed

    assert_select "h1", text: I18n.t("#{scope}.show.headline.error")
    assert_select "[data-controller='assessment--confetti']", 0
    assert_select "#session_result", text: /#{I18n.t("assessment.badges.mastery.struggling")}/
    assert_select "#session_badge", text: /#{I18n.t("assessment.badges.levels.none")}/
    assert_select "button[type=submit]", text: I18n.t("#{scope}.show.restart")
  end

  test "sans faute : Diamant, « Nouveau badge ! », et plus de « Recommencer »" do
    perfect = complete(score_percent: GRADING::PERFECT_THRESHOLD)
    create_badge(student: @student, exercise: @exercise, level: "diamond", session: perfect)
    sign_in_as @student

    show perfect

    assert_select "#session_badge[aria-label=?]", I18n.t("#{scope}.badge.label", level: "Diamant")
    assert_select "#session_badge", text: /#{I18n.t("#{scope}.badge.new")}/
    assert_select "#session_result", text: /20\/20/
    assert_select "form[action='#{exercise_sessions_path(@exercise.public_id)}']", 0
  end
end
