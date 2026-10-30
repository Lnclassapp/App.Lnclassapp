require "application_system_test_case"

# prepare-interros-cahier, Lot C (CA-3, 4, 5, 10, 17 ; UDR feuilles-prepare-interros-et-devoirs §3) : l'élève vérifie un exercice sur la
# feuille de la leçon ; l'exercice corrigé remplace l'ancien sans changer de page, ses refus s'affichent dans l'exercice, réponses gardées.
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
  test "4 justes sur 5 : l'exercice affiche À revoir, la note, la mention et la correction sans changer d'adresse ; un exercice réussi compte" do
    visit course_path(@course.slug)
    address = current_url
    answer(@exercise, [ true, true, true, true, false ])

    within(frame(@exercise)) { click_button "Vérifier ma réponse" }

    within(frame(@exercise)) do
      assert_selector ".ps-status", text: "À revoir"
      assert_selector ".ps-result-grade", text: "Ta note : 8 / 10"
      assert_selector ".ps-result-mention", text: "Mention : Très bien"
      assert_selector ".ps-result-detail", text: "4 bonnes réponses sur 5."
      assert_selector ".ps-correction-item", count: 5
      assert_text "Bonne réponse :", count: 5
      assert_button "Refaire l'exercice"
      assert_no_button "Vérifier ma réponse"
    end
    assert_equal address, current_url
    # Le focus passe à « Ta note ».
    assert_equal "sheet-grade-#{@exercise.public_id}", page.evaluate_script("document.activeElement.id")
    assert_equal 1, Orm::ExerciseSession.where(student: @student, exercise: @exercise, status: "completed").count
    within(".ps-sheet#notion-#{@notion.slug}") { assert_selector ".ps-progress", text: "0 / 4 exercice réussi" }

    answer(@short, [ true ])
    within(frame(@short)) { click_button "Vérifier ma réponse" }

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

    within(frame(@short)) { click_button "Vérifier ma réponse" }
    within(frame(@archived)) { click_button "Vérifier ma réponse" }

    within(frame(@short)) do
      assert_selector "p[role=alert]", text: /Tu as rendu 3 copies d'affilée\. Tu pourras recommencer à \d{2} h \d{2}\./
      assert_selector "button[role=radio][aria-checked=true]", count: 1
      assert_button "Vérifier ma réponse"
    end
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
