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

  # La proposition 1 de chaque question est la bonne (factory) : « A. » ; « B. » est fausse.
  def answer(exercise, rights)
    within(frame(exercise)) do
      all(".ps-question").each_with_index { |question, index| question.click_button(rights[index] ? "A." : "B.") }
    end
  end

  # CA-3, CA-4
  test "4 justes sur 5 : la page de résultat de la copie s'ouvre (note sur 20), le retour ramène à l'exercice, À revoir et Voir ma correction ; un exercice réussi compte" do
    visit course_path(@course.slug)
    answer(@exercise, [ true, true, true, true, false ])

    within(frame(@exercise)) { click_button "Vérifier ma réponse" }

    assert_selector "#session_grade", text: "16/20"
    assert_current_path(%r{\A/sessions/[^/]+/result\?return_to=sheet\z})
    assert_equal 1, Orm::ExerciseSession.where(student: @student, exercise: @exercise, status: "completed").count
    click_link "Retour à la leçon"

    assert_current_path course_path(@course.slug)
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
    click_link "Retour à la leçon"

    within(frame(@short)) { assert_selector ".ps-status", text: "Réussi" }
    within(".ps-sheet#notion-#{@notion.slug}") { assert_selector ".ps-progress", text: "1 / 4 exercice réussi" }
  end

  # CA-5, CA-10, CA-17
  test "la pause, l'exercice archivé et le devoir à rendre s'affichent dans l'exercice, réponses gardées, sans copie" do
    3.times { create_exercise_session(student: @student, exercise: @short, status: "completed", completed_at: 5.minutes.ago) }
    @assigned.update!(hint: "Pense à Thalès.")
    create_assignment(classroom: @classroom, assignable: @assigned)
    visit course_path(@course.slug)

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
end
