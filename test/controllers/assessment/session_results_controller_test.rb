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
      record_medal(session)
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

  # UDR médailles : l'élève lit sa médaille et la prochaine à viser ; ni note, ni score, ni maîtrise. UDR-0140 : le titre reste l'appréciation.
  test "l'élève voit sa médaille Bronze à 10/20, « Assez bien », la prochaine à viser, sans note ni score ni maîtrise" do
    # La médaille vient d'une copie plus ancienne : celle-ci ne la décerne pas (pas de « Nouvelle médaille ! »).
    earlier = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: GRADING::PASS_THRESHOLD)
    Orm::ExerciseBadge.find_by!(student: @student, exercise: @exercise).update!(exercise_session: earlier)
    sign_in_as @student

    show

    assert_response :success
    assert_select "title", text: /Méiose/
    assert_select "h1", text: I18n.t("#{scope}.show.headline.fair")
    assert_select "[data-controller='assessment--confetti']", 0
    assert_select "#session_grade", 0
    assert_select "#session_result dl", 0
    assert_select "#session_result", text: %r{\d+\s*/\s*20|\d+\s*%|barème}, count: 0
    assert_select "#session_result", text: /#{I18n.t("assessment.badges.mastery.fragile")}/, count: 0
    assert_select "#session_next_medal", text: "Prochaine médaille : Argent"
    assert_select "#session_badge[aria-label=?]", I18n.t("#{scope}.badge.label", level: "Bronze")
    assert_select "#session_badge", text: %r{\d+\s*/\s*20|%}, count: 0
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

  # refaire-ou-continuer (UDR §3) : venue d'une feuille, la correction ramène à la feuille : « Refaire l'exercice » (exercice vide) et
  # « Continuer les exercices » (le suivant non fait) ; « Retour à la leçon » quand tout est fait.
  # Une feuille de 3 exercices : @exercise (rang 3 ou 1), puis deux autres ; `done` : ceux dont l'élève a une copie terminée.
  def sheet_of_three(first_rank: 1, done: [])
    @exercise.update!(position: first_rank == 1 ? 10 : 13)
    others = [ 11, 12 ].map { |position| create_exercise(essential: @essential, position:, questions: 1) }
    others.each_with_index do |exercise, index|
      create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 50) if done.include?(index)
    end
    others
  end

  def sheet_anchor = "notion-#{@essential.slug}"
  def exercise_anchor(exercise) = "sheet-exercise-#{exercise.public_id}"
  def from_sheet(session = @session) = get(exercise_session_result_path(session.public_id, return_to: "sheet", sheet: sheet_anchor))
  def fill(**) = fill_course_sheet_path(@essential.course.slug, sheet_anchor, **)

  test "refaire-ou-continuer : « Continuer les exercices » va à l'exercice suivant non fait, « Refaire » rouvre la feuille avec redo" do
    second, = sheet_of_three
    sign_in_as @student

    from_sheet

    assert_select "a#restart-exercise-link[href=?]", fill(redo: @exercise.public_id, anchor: exercise_anchor(@exercise)), text: I18n.t("assessment.exercises.show.redo")
    assert_select "form#restart-exercise-form", 0
    assert_select "a[href=?]", fill(anchor: exercise_anchor(second)), text: I18n.t("#{scope}.show.continue_exercises")
    assert_select ".ui-button-lg", 2
  end

  test "refaire-ou-continuer : « Continuer » revient au premier exercice non fait quand le suivant est déjà fait" do
    first, = sheet_of_three(first_rank: 3, done: [ 1 ])
    sign_in_as @student

    from_sheet

    assert_select "a[href=?]", fill(anchor: exercise_anchor(first)), text: I18n.t("#{scope}.show.continue_exercises")
  end

  test "refaire-ou-continuer : tout est fait, « Retour à la leçon » vers la case de la feuille, sans « Continuer »" do
    sheet_of_three(done: [ 0, 1 ])
    sign_in_as @student

    from_sheet

    assert_select "a[href=?]", course_path(@essential.course.slug, anchor: sheet_anchor), text: I18n.t("#{scope}.show.back_to_lesson")
    assert_select "a", text: I18n.t("#{scope}.show.continue_exercises"), count: 0
  end

  test "refaire-ou-continuer : un devoir de Ma classe, « Reprendre le devoir » vers l'exercice suivant, puis « Retour à Ma classe »" do
    other = create_exercise(essential: @essential, questions: 1)
    teacher = create_teacher(classrooms: [ @classroom ])
    batch = "BATCHREDOXXXX"
    mine, theirs = [ @exercise, other ].map do |exercise|
      create_assignment(classroom: @classroom, assignable: exercise, by: teacher, batch_public_id: batch, assigned_at: 1.hour.ago)
    end
    @session.update!(classroom_assignment_id: mine.id)
    dom_id = "devoir-#{batch.downcase}"
    sign_in_as @student

    get exercise_session_result_path(@session.public_id, return_to: "class", sheet: dom_id)

    assert_select "a[href=?]", fill_student_assigned_sheet_path(dom_id, anchor: exercise_anchor(other)), text: I18n.t("#{scope}.show.back_to_assignment")
    assert_select "a#restart-exercise-link[href=?]", fill_student_assigned_sheet_path(dom_id, redo: @exercise.public_id, anchor: exercise_anchor(@exercise))

    create_exercise_session(student: @student, exercise: other, status: "completed", score_percent: 50, classroom_assignment_id: theirs.id)
    get exercise_session_result_path(@session.public_id, return_to: "class", sheet: dom_id)

    assert_select "a[href=?]", student_classroom_path(anchor: dom_id), text: I18n.t("#{scope}.show.back_to_class")
    assert_select "a", text: I18n.t("#{scope}.show.back_to_assignment"), count: 0
  end

  test "refaire-ou-continuer : feuille introuvable, « Retour à la leçon » et l'ancien « Refaire » en formulaire ; sans feuille, rien ne change" do
    sign_in_as @student

    get exercise_session_result_path(@session.public_id, return_to: "sheet", sheet: "notion-disparue")

    assert_select "form#restart-exercise-form button", text: I18n.t("assessment.exercises.show.redo")
    assert_select "a#restart-exercise-link", 0
    assert_select "a", text: I18n.t("#{scope}.show.back_to_lesson"), count: 1
    assert_select "a", text: I18n.t("#{scope}.show.continue_exercises"), count: 0

    show

    assert_select "form#restart-exercise-form button", text: I18n.t("assessment.exercises.show.redo")
    assert_select "a[href=?]", course_path(@essential.course.slug, anchor: "notion-#{@essential.slug}"), text: I18n.t("#{scope}.show.back_to_lesson")
  end

  test "refaire-ou-continuer : la fiche « à revoir » venue d'une feuille renvoie « Refaire l'exercice » à la feuille avec redo ; sans feuille, à la notion" do
    failed_then_remediated(70)
    sign_in_as @student

    from_sheet

    assert_select "#session_gap_outcome a[href=?]", fill(redo: @exercise.public_id, anchor: exercise_anchor(@exercise)), text: I18n.t("assessment.exercises.show.redo")

    get exercise_session_result_path(@session.public_id, return_to: "sheet", sheet: "notion-disparue")

    assert_select "#session_gap_outcome a[href=?]", course_path(@essential.course.slug, anchor: sheet_anchor), text: I18n.t("assessment.exercises.show.redo")

    show

    assert_select "#session_gap_outcome a[href=?]", course_path(@essential.course.slug, anchor: sheet_anchor), text: I18n.t("assessment.exercises.show.redo")
  end

  test "refaire-ou-continuer : une ancre de devoir d'une AUTRE classe : retour à Ma classe sans ancre, formulaire d'avant, aucun lien vers un devoir" do
    teacher = create_teacher(classrooms: [ @classroom ])
    other_classroom = create_classroom(level: @essential.course.level, name: "Autre classe")
    create_assignment(classroom: other_classroom, assignable: @exercise, by: teacher, batch_public_id: "BATCHAUTRE", assigned_at: 1.hour.ago)
    sign_in_as @student

    get exercise_session_result_path(@session.public_id, return_to: "class", sheet: "devoir-batchautre")

    assert_select "a[href=?]", student_classroom_path, text: I18n.t("#{scope}.show.back_to_class")
    assert_select "a#restart-exercise-link", 0
    assert_select "form#restart-exercise-form", 1
    assert_select "a[href*=?]", "devoir-batchautre", 0
    assert_select "a[href*='/fill']", 0
  end

  test "refaire-ou-continuer : une feuille trouvée mais sans l'exercice de la copie : les boutons d'avant, côté leçon et côté devoir" do
    other_essential = create_essential(course: @essential.course, name: "Autre notion", position: 5)
    create_exercise(essential: other_essential, questions: 1)
    teacher = create_teacher(classrooms: [ @classroom ])
    other = create_exercise(essential: @essential, questions: 1)
    create_assignment(classroom: @classroom, assignable: other, by: teacher, batch_public_id: "BATCHAUTRED", assigned_at: 1.hour.ago)
    sign_in_as @student

    get exercise_session_result_path(@session.public_id, return_to: "sheet", sheet: "notion-#{other_essential.slug}")

    assert_select "form#restart-exercise-form", 1
    assert_select "a#restart-exercise-link", 0
    assert_select "a[href=?]", course_path(@essential.course.slug, anchor: "notion-#{@essential.slug}"), text: I18n.t("#{scope}.show.back_to_lesson")
    assert_select "a", text: I18n.t("#{scope}.show.continue_exercises"), count: 0

    get exercise_session_result_path(@session.public_id, return_to: "class", sheet: "devoir-batchautred")

    assert_select "form#restart-exercise-form", 1
    assert_select "a#restart-exercise-link", 0
    assert_select "a[href=?]", student_classroom_path, text: I18n.t("#{scope}.show.back_to_class")
    assert_select "a", text: I18n.t("#{scope}.show.back_to_assignment"), count: 0
  end

  test "refaire-ou-continuer : feuille trouvée et sans-faute : pas de « Refaire », « Continuer les exercices » reste" do
    sheet_of_three
    perfect = complete(score_percent: 100)
    sign_in_as @student

    from_sheet perfect

    assert_select "a#restart-exercise-link", 0
    assert_select "form#restart-exercise-form", 0
    assert_select "a", text: I18n.t("#{scope}.show.continue_exercises"), count: 1
  end

  test "refaire-ou-continuer : feuille trouvée et pause : l'heure de reprise, ni « Refaire » ni lien redo dans la fiche" do
    sheet_of_three
    @session.update_columns(score_percent: 30, completed_at: Time.zone.local(2026, 1, 1))
    gap = create_gap(student: @student, essential: @essential, source_session: @session)
    travel_to Time.zone.local(2026, 10, 28, 10, 0)
    complete(score_percent: 50, gap:)
    travel_to Time.zone.local(2026, 10, 28, 10, 10)
    complete(score_percent: 50, gap:)
    travel_to Time.zone.local(2026, 10, 28, 10, 20)
    third = complete(score_percent: 50, gap:)
    travel_to Time.zone.local(2026, 10, 28, 10, 25)
    sign_in_as @student

    from_sheet third

    assert_select "#restart_pause", 1
    assert_select "a#restart-exercise-link", 0
    assert_select "#session_gap_outcome", 1
    assert_select "#session_gap_outcome a[href*=redo]", 0
    assert_select "#session_gap_outcome a[href=?]", course_path(@essential.course.slug, anchor: sheet_anchor)
  end

  test "refaire-ou-continuer : l'enseignant qui ouvre la copie avec une feuille ne voit ni « Refaire » ni « Continuer »" do
    sheet_of_three
    sign_in_as create_teacher(classrooms: [ @classroom ])

    from_sheet

    assert_response :success
    assert_select "a#restart-exercise-link", 0
    assert_select "a", text: I18n.t("#{scope}.show.continue_exercises"), count: 0
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

  # CA-08 : « Très bien », les confettis (dès l'Argent) et la médaille Or ; plus de note verte.
  test "à 16/20, « Très bien », la médaille Or et les confettis" do
    @session.update!(score_percent: 80)
    record_medal(@session)
    sign_in_as @student

    show

    assert_select "h1", text: I18n.t("#{scope}.show.headline.very_good")
    assert_select "#session_badge[aria-label=?]", I18n.t("#{scope}.badge.label", level: "Or")
    assert_select "#session_next_medal", text: "Prochaine médaille : Diamant"
    assert_select "#session_grade", 0
    assert_select "[data-controller='assessment--confetti']", 1
  end

  # UDR-0087 §3.6 : les confettis dès « 14/20 » affiché (Argent) ; 67 % reste Bronze, sans confettis.
  test "70 % et 68 % sont Argent avec confettis ; 67 % est Bronze sans confettis ; tous trois « Bien »" do
    sign_in_as @student

    { 70 => [ "Argent", 1 ], 68 => [ "Argent", 1 ], 67 => [ "Bronze", 0 ] }.each do |score, (medal, confetti)|
      @session.update!(score_percent: score)
      record_medal(@session)
      show
      assert_select "h1", text: I18n.t("#{scope}.show.headline.good")
      assert_select "#session_badge[aria-label=?]", I18n.t("#{scope}.badge.label", level: medal)
      assert_select "[data-controller='assessment--confetti']", confetti
    end
  end

  # ADR-0115, CA-02 : sur une copie vérifiée, l'élève lit sa réponse, la proposition correcte et l'explication (UDR-0023 est amendée).
  test "CA-02 : la revue de l'élève : sa réponse, la bonne réponse et l'explication" do
    sign_in_as @student

    show

    assert_select "#question_review_#{@first.id}" do
      assert_select "*", text: /#{I18n.t("#{scope}.show.wrong")}/
      assert_select "*", text: /Combien de cellules donne la méiose \?/
      # UDR-0149 §3 (ajout du 2026-10-31) : l'explication n'est plus sous la question, mais dans le bloc « Correction » de l'exercice.
      assert_select "*", text: /Quatre cellules filles\./, count: 0
      assert_select "ul li", 4
      assert_select "li[data-correct]", text: /#{right(@first).content}/, count: 1
      assert_select "li[data-selected]:not([data-correct])", text: /#{wrong(@first).content}/, count: 1
      assert_select "*", text: /#{I18n.t("#{scope}.question_review.correct")}/
    end
    assert_select "#session_correction", text: /a\. Quatre cellules filles\./
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
      assert_select "*", text: /Quatre cellules filles\./, count: 0
    end
    assert_select "#session_correction", text: /a\. Quatre cellules filles\./
  end

  # UDR-0149 §3 (ajout du 2026-10-31, Touré) : un seul bloc « Correction » sous l'exercice, « a. … b. … » (lettre = rang de la question) ;
  # une question sans explication est sautée sans décaler les lettres ; ✓ / ✗ et bonne réponse restent sur la question.
  test "la correction tient en un bloc sous l'exercice : « a. … », « c. … », la question sans explication sautée" do
    @second.update!(explanation: nil)
    third = add_question(session: @session, explanation: "Trois cellules.")
    sign_in_as @student

    show

    assert_select "#session_review #session_correction", 1
    assert_select "#session_correction h3", text: I18n.t("#{scope}.show.correction")
    assert_select "#session_correction p", 2
    assert_select "#session_correction[data-controller=math]", 1
    assert_select "#session_correction p:nth-of-type(1)", text: "a. Quatre cellules filles."
    assert_select "#session_correction p:nth-of-type(2)", text: "c. Trois cellules."
    assert_select "#session_review ol", text: /Quatre cellules filles/, count: 0
    assert_select "#question_review_#{third.id}", text: /Trois cellules/, count: 0
    assert_select "#question_review_#{@first.id} li[data-correct]", text: /#{right(@first).content}/
  end

  test "sans aucune explication, pas de bloc « Correction »" do
    @first.update!(explanation: nil)
    sign_in_as @student

    show

    assert_select "#session_correction", 0
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
    # retouche : les étiquettes passent à la ligne sous le texte, jamais de troncature
    assert_select "#question_review_#{@first.id} li[data-correct].flex-wrap > [data-answer-labels].flex-wrap", 1
    assert_select "#question_review_#{@first.id} li .truncate", 0
    # retouche : les valeurs des tuiles ne se coupent pas (2×2 dans la colonne de 340 px) ; la tuile elle-même ne bloque
    # pas le retour à la ligne, sinon l'infobulle de la maîtrise, ouverte, déborde à 390 px.
    assert_select "#session_result dl:not([class~='sm:grid-cols-4']) > div > dd.whitespace-nowrap", 4
    assert_select "#session_result dl > div.whitespace-nowrap", 0
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

  # B-039 (audit 2026-11-08): the teacher or the team has no « session » page to be sent to (it answers 403): a copy still in progress
  # is not found for them, and they are not redirected.
  test "B-039 : l'enseignant de la classe et l'équipe n'ont pas de résultat pour une copie en cours : 404, sans redirection" do
    started = create_exercise_session(student: @student, exercise: @exercise)

    { "enseignant" => create_teacher(classrooms: [ @classroom ]), "équipe" => create_team_member }.each do |label, reader|
      sign_in_as reader

      show started

      assert_response :not_found, label
    end
  end

  test "session non terminée : retour à la session" do
    started = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student

    show started

    assert_redirected_to exercise_session_path(started.public_id)
  end

  test "sous 48 % : « À retravailler », médaille Bronze (tout exercice traité), aucun confetti, ni « En difficulté » ni « Pas encore », « Refaire l'exercice »" do
    failed = complete(score_percent: GRADING::PASS_THRESHOLD - 10, first_correct: false)
    sign_in_as @student

    show failed

    assert_select "h1", text: I18n.t("#{scope}.show.headline.needs_work")
    assert_select "[data-controller='assessment--confetti']", 0
    assert_select "#session_badge[aria-label=?]", I18n.t("#{scope}.badge.label", level: "Bronze")
    assert_select "#session_result", text: /#{I18n.t("assessment.badges.mastery.struggling")}|#{I18n.t("#{scope}.badge.none")}|Non acquis/, count: 0
    assert_select "#session_result", text: %r{\d+\s*/\s*20|\d+\s*%|barème}, count: 0
    assert_select "button[type=submit]", text: I18n.t("assessment.exercises.show.redo")
  end

  test "20 % avec réponses : Bronze sans « Nouvelle médaille ! »" do
    low = complete(score_percent: 20, first_correct: false)
    sign_in_as @student

    show low

    assert_select "#session_badge[aria-label=?]", I18n.t("#{scope}.badge.label", level: "Bronze")
    assert_select "#session_badge", text: /#{I18n.t("#{scope}.badge.new")}/, count: 0
  end

  test "sans faute : Diamant, « Nouvelle médaille ! », et plus de « Recommencer »" do
    perfect = complete(score_percent: GRADING::PERFECT_THRESHOLD)
    sign_in_as @student

    show perfect

    assert_select "#session_badge[aria-label=?]", I18n.t("#{scope}.badge.label", level: "Diamant")
    assert_select "#session_badge", text: /#{I18n.t("#{scope}.badge.new")}/
    assert_select "#session_next_medal", 0
    assert_select "#session_result", text: %r{\d+\s*/\s*20|\d+\s*%|barème}, count: 0
    assert_select "form[action='#{exercise_sessions_path(@exercise.public_id)}']", 0
  end

  # ADR-0106 §4.3 : le Diamant est le sans-faute, pas une note. 98 % s'affiche 20/20 mais reste Or et garde « Recommencer ».
  test "98 % : Or, pas Diamant, et « Recommencer » reste" do
    almost = complete(score_percent: 98)
    sign_in_as @student

    show almost

    assert_select "#session_next_medal", text: "Prochaine médaille : Diamant"
    assert_select "#session_badge[aria-label=?]", I18n.t("#{scope}.badge.label", level: "Or")
    assert_select "button[type=submit]", text: I18n.t("assessment.exercises.show.redo")
  end

  test "progrès : aucune phrase à la première session" do
    sign_in_as @student

    show

    assert_select "#session_progress", 0
  end

  test "progrès : 30 puis 90, l'élève lit qu'il progresse, icône verte, entre la médaille et le bouton" do
    current = sessions(30, 90).last
    sign_in_as @student

    show current

    expected = "Tu passes de Bronze à Or. Bravo !"
    assert_equal expected, progress(:progress, first: "Bronze", current: "Or")
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

  test "progrès : 80 puis 80, il confirme sa médaille" do
    current = sessions(80, 80).last
    sign_in_as @student

    show current

    expected = "Tu confirmes ta médaille Or."
    assert_equal expected, progress(:stable, current: "Or")
    assert_select "#session_progress", text: expected
    assert_select "#session_progress svg.text-success", 1
  end

  test "progrès : 30, 90 puis 40, la troisième rappelle son meilleur résultat, la deuxième rouverte son progrès" do
    second, third = sessions(30, 90, 40)
    sign_in_as @student

    show third

    expected = "Ta meilleure médaille reste Or. Relis la correction, tu peux la retrouver."
    assert_equal expected, progress(:decline, best: "Or")
    assert_select "#session_progress", text: expected
    assert_select "#session_progress svg.text-mute", 1
    assert_no_match(/stagne|baisse/i, response.body)

    show second

    assert_select "#session_progress", text: progress(:progress, first: "Bronze", current: "Or")
  end

  # Décision du 2026-10-04 (défaut D1 du challenger) : sous 50 %, la session suivante de la fiche est une remédiation.
  # Elle fait l'exercice : son résultat porte la phrase, et elle compte dans l'historique des sessions d'après.
  test "progrès : 25 puis 75 en remédiation, l'élève lit qu'il progresse sur le résultat de la remédiation" do
    remediation = sessions(25, 75, remediations: [ 2 ]).last
    sign_in_as @student

    show remediation

    assert_select "#session_progress", text: "Tu passes de Bronze à Argent. Bravo !"
    assert_select "#session_progress svg.text-success", 1
  end

  test "progrès : 25, 75 en remédiation, 25, 75 en remédiation, 50 — la 3e et la 5e rappellent sa meilleure médaille, Argent" do
    _, third, _, fifth = sessions(25, 75, 25, 75, 50, remediations: [ 2, 4 ])
    sign_in_as @student
    expected = "Ta meilleure médaille reste Argent. Relis la correction, tu peux la retrouver."

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

  test "fiche : la session qui ouvre la lacune le dit à l'élève, avec la règle en médaille et le lien vers la fiche" do
    failed_then_remediated(70)
    sign_in_as @student

    show

    assert_select "#session_gap_outcome.bg-warning-soft" do
      assert_select "p.font-medium", text: "Cette notion passe à revoir."
      assert_select "p", text: "Refais l'exercice de « Division cellulaire » et vise l'Or."
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
    assert_select "#session_gap_outcome p", text: "Pour lever « Division cellulaire », vise l'Or."
    assert_select "#session_gap_outcome a[href='#{course_path(@essential.course.slug, anchor: "notion-#{@essential.slug}")}']",
                  text: "Refaire l'exercice"
  end

  # Décision du porteur (2026-10-19, ADR-0101 §4.5) : 74 % s'affiche 15/20, la note lue fait foi et lève la fiche.
  test "fiche : une remédiation à 74 % est Argent et « Notion levée ! » : la médaille et l'effet sur la fiche s'accordent" do
    gap, remediation = failed_then_remediated(74)
    decision = Entities::Assessment::GapDecision.call(score_percent: 74, pending_gap: gap, session_kind: remediation.kind)
    assert_equal :remediated, decision
    gap.update!(status: decision.to_s, resolved_at: Time.current, resolved_by_session: remediation)
    sign_in_as @student

    show remediation

    assert_select "#session_badge[aria-label=?]", I18n.t("#{scope}.badge.label", level: "Argent")
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

    { "enseignant" => create_teacher(classrooms: [ @classroom ]), "équipe" => create_team_member }.each do |label, reader|
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
  test "CA-15 : l'élève ne lit plus « points corrigés automatiquement » ; « 4 points à comparer au corrigé » reste, l'enseignant garde les deux" do
    session = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 72)
    # @first (1 pt) et @second (1 pt) existent déjà : on porte l'exercice à 11 points corrigés, dont 6 justes (3 + 3).
    @first.update!(points: 3)
    @second.update!(points: 3)
    create_attempt(session:, question: @first, correct: true)
    create_attempt(session:, question: @second, correct: true)
    add_question(session:, points: 5, correct: false)
    add_question(session:, type: "written", points: 4, explanation: "Corrigé type.")
    record_medal(session)
    sign_in_as @student

    show session

    assert_select "#session_points", text: /4 points à comparer au corrigé/
    assert_select "#session_points", text: /corrigés automatiquement/, count: 0
    assert_select "#session_grade", 0
    assert_select "#session_badge[aria-label=?]", I18n.t("#{scope}.badge.label", level: "Argent")

    sign_in_as create_teacher(classrooms: [ @classroom ])
    show session
    assert_select "#session_points", text: /6 points sur 11 corrigés automatiquement/
    assert_select "#session_grade", text: "14/20"
  end

  test "CA-16 : un exercice tout à 1 point n'affiche aucun point" do
    sign_in_as @student

    show

    assert_select "#session_points", 0
  end

  test "points décimaux : « 1,5 point » au format français, lu par l'enseignant seulement" do
    session = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 60)
    @first.update!(points: 1.5)
    create_attempt(session:, question: @first, correct: true)
    create_attempt(session:, question: @second, correct: false)
    sign_in_as @student

    show session

    assert_select "#session_points", 0

    sign_in_as create_teacher(classrooms: [ @classroom ])
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

  # CA-03 : l'élève propriétaire d'une copie vérifiée lit la solution de chaque type.
  def wrong_attempt(session:, question:, ids: [], text: nil)
    Orm::QuestionAttempt.create!(exercise_session: session, question:, correct: false, selected_answer_ids: ids, response_text: text,
                                 answered_at: Time.current)
  end

  def kind_session(question_type:, answers:)
    exercise = create_exercise(essential: @essential, questions: 0)
    question = create_kind_question(exercise:, question_type:, answers:)
    [ question, create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 0) ]
  end

  test "CA-03 : un texte à trous montre les réponses acceptées" do
    question, session = kind_session(question_type: "fill_blank", answers: %w[Abidjan Yamoussoukro])
    wrong_attempt(session:, question:, text: "Paris")
    sign_in_as @student

    show session

    assert_select "#question_review_#{question.id} [data-correct]", text: /Abidjan ; Yamoussoukro/
  end

  test "CA-03 : un ordre montre le bon ordre" do
    question, session = kind_session(question_type: "ordering", answers: %w[Premier Deuxième Troisième])
    wrong_attempt(session:, question:, ids: question.answers.order(:position).map(&:id).reverse)
    sign_in_as @student

    show session

    assert_select "#question_review_#{question.id} [data-correct] li", count: 3
    assert_select "#question_review_#{question.id} [data-correct]", text: /1\.\s*Premier.*2\.\s*Deuxième.*3\.\s*Troisième/m
  end

  test "CA-03 : une association montre les bonnes paires" do
    question, session = kind_session(question_type: "matching", answers: [ %w[chat miaou], %w[chien aboie] ])
    wrong_attempt(session:, question:, ids: question.answers.order(:position).map(&:id).reverse)
    sign_in_as @student

    show session

    assert_select "#question_review_#{question.id} [data-correct] li", count: 2
    assert_select "#question_review_#{question.id} [data-correct]", text: /chat → miaou.*chien → aboie/m
  end

  test "CA-03 : un choix dans une liste montre la proposition correcte" do
    exercise = create_exercise(essential: @essential, questions: 0)
    question = exercise.questions.create!(position: 1, content: "Choisis", question_type: "select")
    question.answers.create!(position: 1, content: "Proposition juste", correct: true)
    mistaken = question.answers.create!(position: 2, content: "Proposition fausse", correct: false)
    session = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 0)
    wrong_attempt(session:, question:, ids: [ mistaken.id ])
    sign_in_as @student

    show session

    assert_select "#question_review_#{question.id} [data-correct]", text: /Proposition juste/
    assert_select "#question_review_#{question.id} [data-correct]", text: /Proposition fausse/, count: 0
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
