require "application_system_test_case"

# prepare-interros-cahier, Lot C (CA-3, 4, 5, 10, 17 ; UDR feuilles-prepare-interros-et-devoirs §3) : l'élève vérifie un exercice sur la
# feuille de la leçon ; la vérification ouvre la page de résultat de sa copie (Lot C bis), d'où il revient à l'exercice sur la feuille ;
# ses refus s'affichent dans l'exercice, réponses gardées.
class Assessment::SheetCheckTest < ApplicationSystemTestCase
  setup do
    @course = create_course(name: "Thalès")
    @notion = create_essential(course: @course, name: "La propriété de Thalès", position: 1)
    @exercise = create_exercise(essential: @notion, title: "Cinq questions", questions: 5)
    @short = create_exercise(essential: @notion, title: "Court", questions: 1)
    @archived = create_exercise(essential: @notion, title: "Archivé", questions: 1)
    @assigned = create_exercise(essential: @notion, title: "Assigné", questions: 1)
    @classroom = create_classroom(level: @course.level, series: @course.series)
    @student = create_student(classroom: @classroom)
    sign_in_as @student
  end

  def frame(exercise) = "#sheet-exercise-#{exercise.public_id}"
  def sheet_page = fill_course_sheet_path(@course.slug, "notion-#{@notion.slug}")

  # La proposition 1 de chaque question est la bonne (factory) : « A. » ; « B. » est fausse.
  def answer(exercise, rights)
    within(frame(exercise)) do
      all(".ps-question").each_with_index { |question, index| question.click_button(rights[index] ? "A." : "B.") }
    end
  end

  # CA-3, CA-4
  test "4 justes sur 5 : la page de résultat de la copie s'ouvre (note sur 20), le retour ramène à l'exercice, À revoir et Voir ma correction ; un exercice réussi compte" do
    visit sheet_page
    answer(@exercise, [ true, true, true, true, false ])

    within(frame(@exercise)) { click_button "Vérifier ma réponse" }

    assert_selector "#session_grade", text: "16/20"
    assert_current_path(%r{\A/sessions/[^/]+/result\?return_to=sheet&sheet=notion-[a-z0-9-]+\z})
    assert_equal 1, Orm::ExerciseSession.where(student: @student, exercise: @exercise, status: "completed").count
    # Des exercices restent à faire : le second bouton est « Continuer les exercices » (refaire-ou-continuer), vers la même feuille.
    click_link "Continuer les exercices"

    assert_current_path sheet_page
    within(frame(@exercise)) do
      assert_selector ".ps-status", text: "À revoir"
      assert_link "Voir ma correction"
      assert_button "Refaire l'exercice"
      assert_no_button "Vérifier ma réponse"
      assert_no_text "Ta note"
    end
    within(".ps-sheet#notion-#{@notion.slug}") { assert_selector ".ps-progress", text: "0 / 4 exercice réussi" }

    answer(@short, [ true ])
    within(frame(@short)) { click_button "Vérifier ma réponse" }
    assert_selector "#session_grade"
    click_link "Continuer les exercices"

    within(frame(@short)) { assert_selector ".ps-status", text: "Réussi" }
    within(".ps-sheet#notion-#{@notion.slug}") { assert_selector ".ps-progress", text: "1 / 4 exercice réussi" }
  end

  # CA-5, CA-10, CA-17
  # refaire-ou-continuer : « Refaire l'exercice » de la correction rouvre la feuille avec cet exercice vide, les autres gardent leurs réponses.
  test "Refaire depuis la correction : la feuille rouvre l'exercice vide, l'autre garde ses réponses, redo quitte l'adresse" do
    visit sheet_page
    answer(@short, [ true ])
    within(frame(@short)) { click_button "Vérifier ma réponse" }
    assert_selector "#session_grade", text: "20/20"
    click_link "Continuer les exercices"

    answer(@exercise, [ false, false, false, false, false ])
    within(frame(@exercise)) { click_button "Vérifier ma réponse" }
    assert_selector "#session_grade", text: "0/20"
    find("#restart-exercise-link", text: "Refaire l'exercice").click

    assert_current_path sheet_page
    within(frame(@exercise)) do
      assert_button "Vérifier ma réponse"
      assert_no_selector "button[role=radio][aria-checked=true]"
      assert_no_link "Voir ma correction"
    end
    within(frame(@short)) do
      assert_selector ".ps-status", text: "Réussi"
      assert_link "Voir ma correction"
      assert_selector "button[role=radio][aria-checked=true]", count: 1
    end
    # Le cache Turbo ne garde pas la demande : « Lire le sujet » puis « Précédent » laisse la réponse commencée de l'élève.
    find("#{frame(@exercise)} .ps-question:first-of-type").click_button("A.")
    click_link "Lire le sujet"
    assert_no_current_path sheet_page
    page.go_back
    assert_current_path sheet_page
    # Deux images : le temps que Stimulus reconnecte la feuille restaurée du cache Turbo.
    page.evaluate_async_script("requestAnimationFrame(() => requestAnimationFrame(arguments[0]))")
    assert_selector ".ps-sheet"
    within(frame(@exercise)) { assert_selector "button[role=radio][aria-checked=true]", count: 1 }
    # Rechargée sans redo, la feuille garde l'exercice à blanc.
    visit current_url
    within(frame(@exercise)) { assert_button "Vérifier ma réponse" }
  end

  # refaire-ou-continuer UDR §3 « Arrivée sur l'ancre » : le titre de l'exercice visé n'est pas caché sous la barre collante.
  test "Continuer les exercices : le titre de l'exercice visé arrive sous la barre collante, visible" do
    visit sheet_page
    answer(@exercise, [ true, true, true, true, false ])
    within(frame(@exercise)) { click_button "Vérifier ma réponse" }
    assert_selector "#session_grade"
    click_link "Continuer les exercices"
    assert_current_path(/#sheet-exercise-/, url: true)
    # Une figure ou une formule chargée après le saut allonge ce qui précède : le titre doit rester sous la barre.
    page.execute_script(<<~JS)
      document.documentElement.style.overflowAnchor = "none" // sans l'ancrage de défilement du navigateur, qui masquerait l'insertion
      const block = document.createElement("div")
      block.style.height = "300px"
      document.querySelector(".ps-sheet").prepend(block)
    JS
    script = <<~JS
      (() => {
        const bar = document.querySelector("header").getBoundingClientRect().bottom
        const top = document.querySelector("#{frame(@short)} .ps-exercise-head").getBoundingClientRect().top
        return top - bar
      })()
    JS

    assert page.document.synchronize(3) { page.evaluate_script(script).between?(0, 32) || raise(Capybara::ElementNotFound, "titre mal aligné") }
  end

  test "la pause, l'exercice archivé et le devoir à rendre s'affichent dans l'exercice, réponses gardées, sans copie" do
    3.times { create_exercise_session(student: @student, exercise: @short, status: "completed", completed_at: 5.minutes.ago) }
    @assigned.update!(hint: "Pense à Thalès.")
    create_assignment(classroom: @classroom, assignable: @assigned)
    visit sheet_page

    # Les trois copies sont déjà là : l'exercice s'ouvre corrigé, l'élève le refait.
    within(frame(@short)) { click_button "Refaire l'exercice" }
    answer(@short, [ true ])
    answer(@archived, [ true ])
    @archived.update!(status: "archived", archived_at: Time.current)

    # Le formulaire vise toute la page (_top) : Turbo n'en suit qu'un à la fois, on attend la réponse avant d'envoyer le suivant.
    within(frame(@short)) { click_button "Vérifier ma réponse" }
    within(frame(@short)) do
      assert_selector "p[role=alert]", text: /Tu as rendu 3 copies d'affilée\. Tu pourras recommencer à \d{2} h \d{2}\./
      assert_selector "button[role=radio][aria-checked=true]", count: 1
      assert_button "Vérifier ma réponse"
    end
    within(frame(@archived)) { click_button "Vérifier ma réponse" }
    within(frame(@archived)) do
      assert_selector "p[role=alert]", text: "Cet exercice n'existe plus."
      assert_selector "button[role=radio][aria-checked=true]", text: "Proposition 1"
    end
    within(frame(@assigned)) do
      assert_no_button "Vérifier ma réponse"
      assert_no_button "Indice"
      assert_text "Ce devoir est à rendre : ouvre-le dans Ma classe."
      assert_link "Ma classe", href: student_classroom_path
    end
    assert_equal 3, Orm::ExerciseSession.where(student: @student, exercise: @short).count
    assert_equal 0, Orm::ExerciseSession.where(student: @student, exercise: @archived).count
  end

  test "un QCM à deux bonnes réponses annonce « Coche 2 réponses. » ; une seule case cochée : le refus nomme la question, la case reste cochée" do
    multiple = create_exercise(essential: @notion, title: "Multiple", questions: 1)
    question = multiple.questions.create!(position: 2, content: "<p>Deux réponses</p>", question_type: "multiple_correct_2")
    4.times { |rank| question.answers.create!(position: rank + 1, content: "Choix #{rank + 1}", correct: rank < 2) }
    visit sheet_page

    within(frame(multiple)) do
      assert_selector "p.ps-instruction", text: "Coche 2 réponses.", count: 1
      all(".ps-question").first.click_button("A.")
      all(".ps-question").last.click_button("A.")
      click_button "Vérifier ma réponse"
      assert_selector "p[role=alert]", text: "Question b : coche 2 réponses."
      assert_no_text "un nombre est attendu"
      assert_selector "button[role=checkbox][aria-checked=true]", count: 1
    end
    assert_equal 0, Orm::ExerciseSession.where(student: @student, exercise: multiple).count
  end
end
