require "test_helper"

# AS-11, AS-12, AS-13, AS-39 (UDR-0023) : le résultat d'une session terminée — note sur 20 (score en plus hors élève), maîtrise, badge,
# « Félicitations ! » et confettis dès le seuil de réussite, « Courage ! » en dessous, « Recommencer » sous 100.
# L'élève propriétaire y voit ses choix, le verdict et l'explication, jamais les propositions correctes (décision du
# porteur, 881a623) ; l'enseignant d'une classe active de l'élève et l'équipe voient la correction complète.
# UDR-0073 : à partir de sa deuxième session, l'élève lit sous sa note une phrase de progrès, jamais de sanction.
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

  # Sessions terminées une minute après la précédente, à la suite de @session (rescorée au premier score).
  def sessions(first, *scores)
    @session.update!(score_percent: first)
    scores.map do |score_percent|
      travel 1.minute
      complete(score_percent:)
    end
  end

  def progress(key, **) = I18n.t("#{scope}.progress.#{key}", **)

  test "l'élève voit sa note sur 20, sa maîtrise, son badge, « Félicitations ! » et les confettis, sans score redit" do
    sign_in_as @student

    show

    assert_response :success
    assert_select "title", text: /Méiose/
    assert_select "h1", text: I18n.t("#{scope}.show.headline.success")
    assert_select "[data-controller='assessment--confetti']", 1
    assert_select "#session_result", text: /10\/20/
    # UDR-0023, amendement du 2026-10-02 : la note sur 20 seule dit le résultat de l'élève — ni score, ni questions justes (R6).
    assert_select "#session_result dl dt", 2
    assert_select "#session_result dl dt", text: I18n.t("#{scope}.show.grade")
    assert_select "#session_result dl dt", text: /#{I18n.t("#{scope}.show.mastery")}/
    assert_select "#session_result dd", text: /#{GRADING::PASS_THRESHOLD} %/, count: 0
    assert_select "#session_result dt", text: I18n.t("#{scope}.show.correct"), count: 0
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
    # La correction se lit sans phrase d'aide (R4), 3 cartes puis « Voir plus » (R3) : 2 cartes ici, aucun bouton.
    assert_select "#session_review p", text: I18n.t("#{scope}.show.review_hint_student"), count: 0
    assert_select "#session_review[data-controller=reveal][data-reveal-step-value='3']"
    assert_select "#session_review li[id^=question_review_][data-reveal-target=item]", 2
    assert_select "#session_review [data-reveal-target=button]", 0
  end

  test "l'enseignant d'une classe active de l'élève voit la correction complète, propositions correctes marquées" do
    teacher = create_teacher(classrooms: [ @classroom ])
    sign_in_as teacher

    show

    assert_response :success
    assert_select "#session_result", text: /Mariam Traoré/
    # Décision du porteur (2026-10-02) : l'enseignant garde le résultat inchangé — note, score, maîtrise, questions justes.
    assert_select "#session_result dl dt", 4
    assert_select "#session_result dd", text: "#{GRADING::PASS_THRESHOLD} %"
    assert_select "#session_result", text: /#{I18n.t("#{scope}.show.correct_value", count: 1, total: 2)}/
    assert_select "#session_review p", text: I18n.t("#{scope}.show.review_hint_reveal")
    assert_select "#session_review [data-reveal-target]", 0
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

  test "progrès : aucune phrase à la première session" do
    sign_in_as @student

    show

    assert_select "#session_progress", 0
  end

  test "progrès : 30 puis 90, l'élève lit qu'il progresse, icône verte, entre la note et les boutons" do
    current = sessions(30, 90).last
    sign_in_as @student

    show current

    expected = "Tu progresses : 6/20 à ta première session, 18/20 aujourd'hui."
    assert_equal expected, progress(:progress, first: 6, current: 18)
    assert_select "#session_result dl + p#session_progress + div form#restart-exercise-form"
    assert_select "p#session_progress.text-sm.text-ink", text: expected
    assert_select "#session_progress svg.text-success[aria-hidden=true]", 1
  end

  test "progrès : 60 puis 60, il reste autour de 12/20 et relit la correction, sans « stagne » ni « baisse »" do
    current = sessions(60, 60).last
    sign_in_as @student

    show current

    expected = "Tu restes autour de 12/20. Relis la correction ci-dessous avant de recommencer."
    assert_equal expected, progress(:stagnant, current: 12)
    assert_select "#session_progress", text: expected
    assert_select "#session_progress svg.text-mute", 1
    assert_no_match(/stagne|baisse/i, response.body)
  end

  test "progrès : 80 puis 80, il confirme sa maîtrise" do
    current = sessions(80, 80).last
    sign_in_as @student

    show current

    expected = "Tu confirmes ta maîtrise : 16/20."
    assert_equal expected, progress(:stable, current: 16)
    assert_select "#session_progress", text: expected
    assert_select "#session_progress svg.text-success", 1
  end

  test "progrès : 30, 90 puis 40, la troisième rappelle son meilleur résultat, la deuxième rouverte son progrès" do
    second, third = sessions(30, 90, 40)
    sign_in_as @student

    show third

    expected = "Ton meilleur résultat reste 18/20. Relis la correction, tu peux le retrouver."
    assert_equal expected, progress(:decline, best: 18)
    assert_select "#session_progress", text: expected
    assert_select "#session_progress svg.text-mute", 1
    assert_no_match(/stagne|baisse/i, response.body)

    show second

    assert_select "#session_progress", text: progress(:progress, first: 6, current: 18)
  end

  test "progrès : aucune couleur de sanction dans la phrase, quel que soit le cas" do
    sign_in_as @student

    sessions(30, 90, 40).each do |session|
      show session

      assert_select "#session_progress" do
        assert_select "[class*=error], [class*=warning], [class*=struggling], [class*=fragile]", 0
      end
    end
    assert_select "#session_progress[class*=error], #session_progress[class*=warning]", 0
  end

  test "progrès : l'enseignant de la classe ne voit aucune phrase sur la deuxième session de l'élève" do
    current = sessions(30, 90).last
    sign_in_as create_teacher(classrooms: [ @classroom ])

    show current

    assert_response :success
    assert_select "#session_progress", 0
  end
end
