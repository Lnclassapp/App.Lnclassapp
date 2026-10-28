require "test_helper"

# AS-11, AS-12, AS-13, AS-39 (UDR-0023, UDR-0140) : le résultat d'une session terminée — appréciation (« Très bien » à « À retravailler »),
# note sur 20 (score en plus hors élève), maîtrise, badge, confettis dès le seuil de réussite, « Refaire l'exercice » sous 100.
# ADR-0115 : l'élève propriétaire d'une copie vérifiée y lit la correction complète (sa réponse, la bonne réponse, l'explication) ;
# l'enseignant d'une classe active de l'élève et l'équipe la lisent aussi, avec le texte des réponses rédigées.
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

  def complete(score_percent:, first_correct: true, student: @student, gap: nil)
    create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent:, gap:).tap do |session|
      create_attempt(session:, question: @first, correct: first_correct)
      create_attempt(session:, question: @second, correct: true)
    end
  end

  def show(session = @session) = get(exercise_session_result_path(session.public_id))

  # Sessions terminées une minute après la précédente, à la suite de @session (rescorée au premier score). remediations :
  # les rangs (2 pour la deuxième session) faits en remédiation, sur une lacune de la fiche (ADR-0043).
  def sessions(first, *scores, remediations: [])
    @session.update!(score_percent: first)
    gap = create_gap(student: @student, essential: @essential) if remediations.any?
    scores.each_with_index.map do |score_percent, index|
      travel 1.minute
      complete(score_percent:, gap: (gap if remediations.include?(index + 2)))
    end
  end

  def progress(key, **) = I18n.t("#{scope}.progress.#{key}", **)

  # UDR-0087 §3.6 : la note verte et les confettis à partir de 14/20 ; UDR-0140 : le titre est l'appréciation, 10/20 lit « Assez bien ».
  test "l'élève voit sa note sur 20, sa maîtrise, son badge, « Assez bien » à 10/20, sans score redit" do
    sign_in_as @student

    show

    assert_response :success
    assert_select "title", text: /Méiose/
    assert_select "h1", text: I18n.t("#{scope}.show.headline.fair")
    assert_select "[data-controller='assessment--confetti']", 0
    assert_select "#session_grade.text-success", 0
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
    assert_select "a[href='#{course_path(@essential.course.slug, anchor: "notion-#{@essential.slug}")}']", text: I18n.t("#{scope}.show.back_to_lesson")
    assert_select "form[method=post][action='#{exercise_sessions_path(@exercise.public_id)}']" do
      assert_select "button[type=submit]", text: I18n.t("assessment.exercises.show.redo")
    end
  end

  # UDR-0138 §3.4 : « Refaire l'exercice » puis « Retour à la leçon » ; ni « Revoir l'exercice » ni l'encadré « Tu restes autour de… ».
  test "CA-E5: the student's result has two buttons, « Refaire l'exercice » then « Retour à la leçon »" do
    sign_in_as @student

    show

    assert_select ".ui-button-lg", 2
    assert_select "form#restart-exercise-form button[type=submit].ui-button-lg", text: I18n.t("assessment.exercises.show.redo")
    assert_select "a[href='#{exercise_path(@exercise.public_id)}']", 0
    assert_no_match(/Revoir l'exercice/, response.body)
  end

  # CA-E13 (UDR écrans élève §3.6 bis) : dès 1 024 px, une colonne de gauche de 340 px collante (badge, note, « Recommencer »),
  # la correction à droite.
  test "CA-E13: the result in a sticky 340 px left column, the review on the right" do
    sign_in_as @student

    show

    assert_select "#session_result_layout[class~='lg:grid-cols-side-main']" do
      assert_select "> #session_result_side.lg\\:sticky" do
        assert_select "#session_result"
        assert_select "form#restart-exercise-form"
      end
      assert_select "> #session_review"
    end
  end

  # CA-08 : 16/20, « Très bien », la note verte et les confettis.
  test "à 16/20, « Très bien », la note verte et les confettis" do
    @session.update!(score_percent: 80)
    sign_in_as @student

    show

    assert_select "h1", text: I18n.t("#{scope}.show.headline.very_good")
    assert_select "#session_grade.text-success", text: "16/20"
    assert_select "[data-controller='assessment--confetti']", 1
  end

  # UDR-0087 §3.6 : dès « 14/20 » affiché, la règle de l'historique, de « Ma classe » et de l'accueil.
  test "70 % et 68 % s'affichent 14/20 en vert ; 67 % s'affiche 13/20 sans vert ; tous trois « Bien »" do
    sign_in_as @student

    { 70 => [ "14/20", :success ], 68 => [ "14/20", :success ], 67 => [ "13/20", :error ] }.each do |score, (grade, tone)|
      @session.update!(score_percent: score)
      show
      assert_select "h1", text: I18n.t("#{scope}.show.headline.good")
      assert_select "#session_grade#{".text-success" if tone == :success}", text: grade
      assert_select "#session_grade.text-success", 0 if tone == :error
    end
  end

  # ADR-0115, CA-02 : sur une copie vérifiée, l'élève lit sa réponse, la proposition correcte et l'explication (UDR-0023 est amendée).
  test "CA-02 : la revue de l'élève : sa réponse, la bonne réponse et l'explication" do
    sign_in_as @student

    show

    assert_select "#question_review_#{@first.id}" do
      assert_select "*", text: /#{I18n.t("#{scope}.show.wrong")}/
      assert_select "*", text: /Combien de cellules donne la méiose \?/
      assert_select "*", text: /Quatre cellules filles\./
      assert_select "ul li", 4
      assert_select "li[data-correct]", text: /#{right(@first).content}/, count: 1
      assert_select "li[data-selected]:not([data-correct])", text: /#{wrong(@first).content}/, count: 1
      assert_select "*", text: /#{I18n.t("#{scope}.question_review.correct")}/
    end
    assert_select "#question_review_#{@second.id}", text: /#{I18n.t("#{scope}.show.correct")}/
    assert_select "#question_review_#{@second.id} li[data-correct][data-selected]", 1
    # La correction se lit sans phrase d'aide (R4), 3 cartes puis « Voir plus » (R3) : 2 cartes ici, aucun bouton.
    assert_select "#session_review p", text: I18n.t("#{scope}.show.review_hint_student"), count: 0
    assert_select "#session_review[data-controller=reveal][data-reveal-step-value='3']"
    assert_select "#session_review li[id^=question_review_][data-reveal-target=item]", 2
    assert_select "#session_review [data-reveal-target=button]", 0
  end

  # CA-04 : une question laissée vide dit « Sans réponse », avec sa bonne réponse et son explication.
  test "CA-04 : une question sans réponse porte « Sans réponse », sa bonne réponse et son explication" do
    Orm::QuestionAttempt.where(exercise_session: @session, question: @first).delete_all
    Orm::QuestionAttempt.create!(exercise_session: @session, question: @first, correct: false, selected_answer_ids: [], unanswered: true,
                                 answered_at: Time.current)
    sign_in_as @student

    show

    assert_select "#question_review_#{@first.id}" do
      assert_select "*", text: /#{I18n.t("#{scope}.show.unanswered")}/
      assert_select "li[data-correct]", text: /#{right(@first).content}/
      assert_select "li[data-selected]", 0
      assert_select "*", text: /Quatre cellules filles\./
    end
  end

  # CA-06 : une copie abandonnée n'a pas de correction ; une copie en cours non plus (CA-07).
  test "CA-06 : une copie abandonnée ou en cours ne rend aucune correction" do
    sign_in_as @student
    %w[abandoned started].each do |status|
      copy = create_exercise_session(student: @student, exercise: @exercise, status:)
      create_attempt(session: copy, question: @first, correct: true)

      show copy

      assert_response :redirect
      assert_no_match(/Quatre cellules filles|#{right(@first).content}/, response.body)
    end
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

  test "sous le seuil de réussite : « À retravailler », « En difficulté », « Pas encore de badge », aucun confetti, « Refaire l'exercice »" do
    failed = complete(score_percent: GRADING::PASS_THRESHOLD - 10, first_correct: false)
    sign_in_as @student

    show failed

    assert_select "h1", text: I18n.t("#{scope}.show.headline.needs_work")
    assert_select "[data-controller='assessment--confetti']", 0
    assert_select "#session_result", text: /#{I18n.t("assessment.badges.mastery.struggling")}/
    assert_select "#session_badge", text: /#{I18n.t("#{scope}.badge.none")}/
    assert_select "#session_badge", text: /#{I18n.t("assessment.badges.levels.none")}/, count: 0
    assert_select "button[type=submit]", text: I18n.t("assessment.exercises.show.redo")
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

  # ADR-0106 §4.3 : le Diamant est le sans-faute, pas une note. 98 % s'affiche 20/20 mais reste Or et garde « Recommencer ».
  test "98 % s'affiche 20/20 : Or, pas Diamant, et « Recommencer » reste" do
    almost = complete(score_percent: 98)
    create_badge(student: @student, exercise: @exercise, level: "gold", session: almost)
    sign_in_as @student

    show almost

    assert_select "#session_result", text: /20\/20/
    assert_select "#session_badge[aria-label=?]", I18n.t("#{scope}.badge.label", level: "Or")
    assert_select "button[type=submit]", text: I18n.t("assessment.exercises.show.redo")
  end

  test "progrès : aucune phrase à la première session" do
    sign_in_as @student

    show

    assert_select "#session_progress", 0
  end

  test "progrès : 30 puis 90, l'élève lit qu'il progresse, icône verte, entre la note et le bouton" do
    current = sessions(30, 90).last
    sign_in_as @student

    show current

    expected = "Tu progresses : 6/20 à ta première session, 18/20 aujourd'hui."
    assert_equal expected, progress(:progress, first: 6, current: 18)
    assert_select "#session_result + p#session_progress + form#restart-exercise-form"
    assert_select "p#session_progress.text-sm.text-ink", text: expected
    assert_select "#session_progress svg.text-success[aria-hidden=true]", 1
  end

  test "progrès : 60 puis 60, il reste autour de 12/20 et relit la correction, sans « stagne » ni « baisse »" do
    current = sessions(60, 60).last
    sign_in_as @student

    show current

    # CA-E5 (UDR écrans élève §3.5) : l'encadré « Tu restes autour de… » n'existe plus.
    assert_select "#session_progress", 0
    assert_no_match(/Tu restes autour de/, response.body)
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

  # Décision du 2026-10-04 (défaut D1 du challenger) : sous 50 %, la session suivante de la fiche est une remédiation.
  # Elle fait l'exercice : son résultat porte la phrase, et elle compte dans l'historique des sessions d'après.
  test "progrès : 25 puis 75 en remédiation, l'élève lit qu'il progresse sur le résultat de la remédiation" do
    remediation = sessions(25, 75, remediations: [ 2 ]).last
    sign_in_as @student

    show remediation

    assert_select "#session_progress", text: "Tu progresses : 5/20 à ta première session, 15/20 aujourd'hui."
    assert_select "#session_progress svg.text-success", 1
  end

  test "progrès : 25, 75 en remédiation, 25, 75 en remédiation, 50 — la 3e et la 5e rappellent son meilleur, 15/20" do
    _, third, _, fifth = sessions(25, 75, 25, 75, 50, remediations: [ 2, 4 ])
    sign_in_as @student
    expected = "Ton meilleur résultat reste 15/20. Relis la correction, tu peux le retrouver."

    [ third, fifth ].each do |session|
      show session

      assert_select "#session_progress", text: expected
      assert_select "#session_progress svg.text-mute", 1
    end
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

  # UDR-0120, ADR-0101 §4.3 : une ligne dit à l'élève ce qu'il advient de sa fiche ; l'enseignant et l'équipe ne la lisent pas.
  def gap_outcome(key, **) = I18n.t("#{scope}.gap_outcome.#{key}", **)

  def failed_then_remediated(score_percent)
    @session.update!(score_percent: 30)
    gap = create_gap(student: @student, essential: @essential, source_session: @session)
    travel 1.minute
    [ gap, complete(score_percent:, gap:) ]
  end

  test "fiche : la session qui ouvre la lacune le dit à l'élève, avec la règle sur 20 et le lien vers la fiche" do
    failed_then_remediated(70)
    sign_in_as @student

    show

    assert_select "#session_gap_outcome.bg-warning-soft" do
      assert_select "p.font-medium", text: "Cette notion passe à revoir."
      assert_select "p", text: "Refais l'exercice de « Division cellulaire » et vise au moins 15/20."
      assert_select "a[href='#{course_path(@essential.course.slug, anchor: "notion-#{@essential.slug}")}']", text: "Refaire l'exercice"
    end
    assert_no_match(/75 %/, response.body)
  end

  test "fiche : une remédiation à 14/20 garde ses confettis, lit « Bien », et dit « Encore à revoir »" do
    _, remediation = failed_then_remediated(70)
    sign_in_as @student

    show remediation

    assert_select "h1", text: I18n.t("#{scope}.show.headline.good")
    assert_select "[data-controller='assessment--confetti']", 1
    assert_select "#session_gap_outcome p.font-medium", text: gap_outcome("still_pending.message")
    assert_select "#session_gap_outcome p", text: "Pour lever « Division cellulaire », vise au moins 15/20."
    assert_select "#session_gap_outcome a[href='#{course_path(@essential.course.slug, anchor: "notion-#{@essential.slug}")}']",
                  text: "Refaire l'exercice"
  end

  # Décision du porteur (2026-10-19, ADR-0101 §4.5) : 74 % s'affiche 15/20, la note lue fait foi et lève la fiche.
  test "fiche : une remédiation à 74 % lit 15/20 et « Notion levée ! » : la note et l'effet sur la fiche s'accordent" do
    gap, remediation = failed_then_remediated(74)
    decision = Entities::Assessment::GapDecision.call(score_percent: 74, pending_gap: gap, session_kind: remediation.kind)
    assert_equal :remediated, decision
    gap.update!(status: decision.to_s, resolved_at: Time.current, resolved_by_session: remediation)
    sign_in_as @student

    show remediation

    assert_select "*", text: /15\s*\/\s*20/
    assert_select "#session_gap_outcome.bg-success-soft p.font-medium", text: "Notion levée !"
    assert_select "#session_gap_outcome a", 0
  end

  test "fiche : la remédiation qui lève la fiche lit « Notion levée ! », sans lien, après la phrase de progrès" do
    gap, remediation = failed_then_remediated(80)
    gap.update!(status: "remediated", resolved_at: Time.current, resolved_by_session: remediation)
    sign_in_as @student

    show remediation

    assert_select "#session_gap_outcome.bg-success-soft" do
      assert_select "p.font-medium", text: "Notion levée !"
      assert_select "p", text: "« Division cellulaire » n'est plus à revoir."
      assert_select "a", 0
    end
    assert_match(/id="session_progress".*id="session_gap_outcome"/m, response.body)
  end

  test "fiche : relu après une levée par une autre session, le résultat d'une remédiation ne dit rien de la fiche" do
    gap, short = failed_then_remediated(60)
    travel 1.minute
    gap.update!(status: "remediated", resolved_at: Time.current, resolved_by_session: complete(score_percent: 90, gap:))
    sign_in_as @student

    show short

    assert_select "#session_gap_outcome", 0
  end

  test "fiche : l'enseignant et l'équipe ne lisent pas la ligne de l'élève" do
    gap, remediation = failed_then_remediated(80)
    gap.update!(status: "remediated", resolved_at: Time.current, resolved_by_session: remediation)

    [ create_teacher(classrooms: [ @classroom ]), create_team_member ].each do |reader|
      sign_in_as reader

      show remediation

      assert_response :success
      assert_select "#session_gap_outcome", 0
    end
  end

  # --- ADR-0115 / UDR-0140 : appréciation, « À revoir », points, réponse rédigée, pause ---

  # Une question de plus à l'exercice, avec son attempt, dans la copie donnée.
  def add_question(session:, type: "single_choice", points: 1, correct: true, response_text: nil, explanation: nil, criteria: [], unit: nil)
    position = @exercise.questions.maximum(:position) + 1
    question = @exercise.questions.create!(position:, content: "Question #{position}", question_type: type, points:, explanation:, criteria:, unit:)
    if type == "single_choice"
      4.times { |rank| question.answers.create!(position: rank + 1, content: "Réponse #{position}.#{rank + 1}", correct: rank.zero?) }
      create_attempt(session:, question:, correct:)
    elsif type == "written"
      Orm::QuestionAttempt.create!(exercise_session: session, question:, correct: false, selected_answer_ids: [], response_text:,
                                   unanswered: response_text.nil?, answered_at: Time.current)
    end
    question
  end

  test "CA-09 : exercice de notion, l'élève lit la notion et les questions en cause, avec un lien vers chacune" do
    @session.update!(score_percent: 0)
    Orm::QuestionAttempt.where(exercise_session: @session, question: @second).update_all(correct: false)
    sign_in_as @student

    show

    assert_select "#session_to_review", text: /À revoir : « Division cellulaire », questions 1 et 2/
    assert_select "#session_to_review a[href='#question_review_#{@first.id}']", text: "1"
    assert_select "#session_to_review a[href='#question_review_#{@second.id}']", text: "2"
  end

  test "CA-10 : exercice de toute la leçon, « À revoir dans la leçon » avec le lien « Toute la leçon », sans notion" do
    exercise = create_lesson_wide_exercise(course: @essential.course, questions: 3)
    first, second, third = exercise.questions.order(:position).to_a
    session = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 66)
    [ [ first, true ], [ second, true ], [ third, false ] ].each { |question, correct| create_attempt(session:, question:, correct:) }
    sign_in_as @student

    show session

    assert_select "#session_to_review", text: /À revoir dans la leçon : question 3/
    assert_select "#session_to_review a[href='#{course_path(@essential.course.slug, anchor: "toute-la-lecon")}']", text: "Toute la leçon"
    assert_no_match(/Division cellulaire/, css_select("#session_to_review").to_s)
  end

  test "CA-11 : une copie sans faute lit « Très bien », rien à revoir et pas de « Refaire l'exercice »" do
    perfect = complete(score_percent: 100)
    sign_in_as @student

    show perfect

    assert_select "h1", text: I18n.t("#{scope}.show.headline.very_good")
    assert_select "#session_to_review", 0
    assert_select "form#restart-exercise-form", 0
  end

  test "CA-12 : à 13/20 le titre est « Bien », sans « Félicitations ! » ni « Courage ! », suivi d'une phrase d'encouragement" do
    @session.update!(score_percent: 65)
    sign_in_as @student

    show

    assert_select "h1", text: "Bien"
    assert_no_match(/Félicitations|Courage/, response.body)
    assert_select "#session_result p.text-ink.text-balance", 1
  end

  # CA-15 : 11 points corrigés automatiquement, une réponse rédigée de 4 points.
  test "CA-15 : « 8 points sur 11 corrigés automatiquement » et « 4 points à comparer au corrigé »" do
    session = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 72)
    # @first (1 pt) et @second (1 pt) existent déjà : on porte l'exercice à 11 points corrigés, dont 8 justes.
    @first.update!(points: 3)
    @second.update!(points: 3)
    create_attempt(session:, question: @first, correct: true)
    create_attempt(session:, question: @second, correct: true)
    add_question(session:, points: 5, correct: false)
    add_question(session:, type: "written", points: 4, explanation: "Corrigé type.")
    sign_in_as @student

    show session

    assert_select "#session_points", text: /6 points sur 11 corrigés automatiquement/
    assert_select "#session_points", text: /4 points à comparer au corrigé/
    assert_select "#session_grade", text: "14/20"
  end

  test "CA-16 : un exercice tout à 1 point n'affiche aucun point" do
    sign_in_as @student

    show

    assert_select "#session_points", 0
  end

  test "points décimaux : « 1,5 point » au format français" do
    session = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 60)
    @first.update!(points: 1.5)
    create_attempt(session:, question: @first, correct: true)
    create_attempt(session:, question: @second, correct: false)
    sign_in_as @student

    show session

    assert_select "#session_points", text: /1,5 point sur 2,5 corrigés automatiquement/
  end

  # CA-13 + menace W1 : le texte rédigé est rendu en clair, échappé, à l'élève comme à l'enseignant.
  test "CA-13, W1 : l'enseignant lit l'appréciation, les questions en cause et le texte rédigé en clair, sans phrase d'encouragement" do
    @session.update!(score_percent: 45)
    Orm::QuestionAttempt.where(exercise_session: @session, question: @second).update_all(correct: false)
    written = add_question(session: @session, type: "written", response_text: "Non, car <b>AM/AB</b> <script>alert(1)</script>",
                           explanation: "Corrigé : oui.", criteria: [ "Je cite le théorème", "Je conclus" ])
    sign_in_as create_teacher(classrooms: [ @classroom ])

    show

    assert_response :success
    assert_select "h1", text: I18n.t("#{scope}.show.headline.needs_work")
    assert_select "#session_to_review", text: /questions 1 et 2/
    assert_select "#session_result p.text-balance", 0
    assert_select "#question_review_#{written.id} [data-written-answer]", text: "Non, car <b>AM/AB</b> <script>alert(1)</script>"
    assert_select "#question_review_#{written.id} [data-written-answer] b, #question_review_#{written.id} script", 0
    assert_includes response.body, "Non, car &lt;b&gt;AM/AB&lt;/b&gt; &lt;script&gt;alert(1)&lt;/script&gt;"
    assert_not_includes response.body, "<script>alert(1)"
    assert_select "#question_review_#{written.id}", text: /#{I18n.t("#{scope}.question_review.compare")}/
    assert_select "#question_review_#{written.id}", text: /Corrigé : oui\./
    assert_select "#question_review_#{written.id} fieldset input[type=checkbox]", 2
    assert_select "#question_review_#{written.id} fieldset input[name]", 0
  end

  test "CA-21 : l'élève relit son texte rédigé ; vide, « Tu n'as rien écrit. » ; la question n'est jamais en cause" do
    written = add_question(session: @session, type: "written", response_text: "Mon texte <i>libre</i>", explanation: "Corrigé type.")
    empty = add_question(session: @session, type: "written", explanation: "Autre corrigé.")
    sign_in_as @student

    show

    assert_select "#question_review_#{written.id} [data-written-answer]", text: "Mon texte <i>libre</i>"
    assert_select "#question_review_#{written.id} i", 0
    assert_select "#question_review_#{written.id}", text: /Corrigé type\./
    assert_select "#question_review_#{empty.id}", text: /#{I18n.t("#{scope}.question_review.nothing_written")}/
    assert_select "#question_review_#{empty.id}", text: /Autre corrigé\./
    assert_select "#session_to_review", text: /À revoir : « Division cellulaire », question 1\z/
  end

  # Menace W6 : l'enseignant d'une autre école ne lit ni la copie, ni le texte rédigé.
  test "W1, W6 : un enseignant d'une autre école ouvre le résultat d'une copie vérifiée avec un texte rédigé : refusé, texte absent" do
    add_question(session: @session, type: "written", response_text: "Texte secret de Mariam", explanation: "Corrigé secret.")
    sign_in_as create_teacher(classrooms: [ create_classroom ])

    show

    assert_response :forbidden
    assert_no_match(/Texte secret de Mariam|Corrigé secret/, response.body)
  end

  test "W6 : un autre élève ne lit pas la copie ni son texte rédigé" do
    add_question(session: @session, type: "written", response_text: "Texte secret de Mariam", explanation: "Corrigé secret.")
    sign_in_as create_student(classroom: @classroom)

    show

    assert_response :forbidden
    assert_no_match(/Texte secret de Mariam|Corrigé secret/, response.body)
  end

  test "CA-24 : un travail sur le cahier montre « À comparer au corrigé » et son corrigé, sans champ ni verdict" do
    notebook = @exercise.questions.create!(position: 3, content: "Sur ton cahier, trace la construction.", question_type: "notebook",
                                           points: 2, explanation: "Corrigé de la construction.")
    sign_in_as @student

    show

    assert_select "#question_review_#{notebook.id}" do
      assert_select "*", text: /#{I18n.t("#{scope}.question_review.compare")}/
      assert_select "*", text: /Corrigé de la construction\./
      assert_select "input, textarea", 0
    end
    assert_select "#session_to_review", text: /question 1\z/
  end

  test "CA-03 : une réponse chiffrée en cm montre la valeur attendue suivie de « cm »" do
    exercise = create_exercise(essential: @essential, questions: 0)
    question = create_kind_question(exercise:, question_type: "numeric", answers: [ "4,8" ], numeric_tolerance: 0)
    question.update!(unit: "cm")
    session = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 0)
    Orm::QuestionAttempt.create!(exercise_session: session, question:, correct: false, selected_answer_ids: [], response_text: "5",
                                 answered_at: Time.current)
    sign_in_as @student

    show session

    assert_select "#question_review_#{question.id} [data-correct]", text: /4,8 cm/
  end

  test "CA-34 : après 3 copies d'affilée, l'élève lit l'heure de reprise, sans « Refaire l'exercice »" do
    @session.update_columns(completed_at: Time.zone.local(2026, 1, 1))
    travel_to Time.zone.local(2026, 10, 28, 10, 0)
    complete(score_percent: 50)
    travel_to Time.zone.local(2026, 10, 28, 10, 10)
    complete(score_percent: 50)
    travel_to Time.zone.local(2026, 10, 28, 10, 20)
    third = complete(score_percent: 50)
    travel_to Time.zone.local(2026, 10, 28, 10, 25)
    sign_in_as @student

    show third

    assert_select "#restart_pause", text: "Tu pourras recommencer à 10 h 50."
    assert_select "form#restart-exercise-form", 0
    assert_select "a", text: I18n.t("#{scope}.show.back_to_lesson")
  end

  test "CA-31 : sans copies d'affilée, « Refaire l'exercice » reste proposé" do
    @session.update_columns(completed_at: Time.zone.local(2026, 1, 1))
    travel_to Time.zone.local(2026, 10, 28, 10, 0)
    complete(score_percent: 50)
    travel_to Time.zone.local(2026, 10, 28, 10, 40)
    complete(score_percent: 50)
    travel_to Time.zone.local(2026, 10, 28, 10, 50)
    third = complete(score_percent: 50)
    sign_in_as @student

    show third

    assert_select "#restart_pause", 0
    assert_select "form#restart-exercise-form"
  end

  test "l'enseignant ne lit jamais la phrase de pause" do
    @session.update_columns(completed_at: Time.zone.local(2026, 1, 1))
    travel_to Time.zone.local(2026, 10, 28, 10, 0)
    3.times { complete(score_percent: 50); travel 5.minutes }
    sign_in_as create_teacher(classrooms: [ @classroom ])

    show

    assert_select "#restart_pause", 0
  end
end
