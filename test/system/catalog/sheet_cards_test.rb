require "application_system_test_case"

# sujet-avant-de-commencer, Lot A (UDR feuilles-en-cases-lues-avant-de-commencer) : la leçon montre des cases ; la case ouvre le sujet en
# lecture ; « Commencer » ouvre la feuille à remplir ; la vérification ramène à la feuille ; la case dit le progrès et « Continuer ».
class Catalog::SheetCardsTest < ApplicationSystemTestCase
  setup do
    @course = create_course(name: "Thalès")
    @notion = create_essential(course: @course, name: "La propriété de Thalès", position: 1)
    @subject = create_subject(course: @course, title: "Sujet 2 · Démontrer")
    @exercises = Array.new(4) { |n| create_exercise(subject: @subject, course: @course, title: "Devoir #{n + 1}", position: 10 + n, questions: 1) }
    @student = create_student(classroom: create_classroom(level: @course.level, series: @course.series))
    sign_in_as @student
  end

  def frame(exercise) = "#sheet-exercise-#{exercise.public_id}"

  test "case, lecture, Commencer, vérifier, retour à la feuille, puis « Continuer » et le progrès sur la case" do
    visit course_path(@course.slug)
    assert_selector "a.ps-card", count: 1
    assert_no_selector ".ps-sheet"
    assert_no_button "Vérifier ma réponse"
    assert_selector "#sujet-#{@subject.position} .ps-card-meta", text: "0 / 4 exercice réussi"

    click_link "Prépare devoirs n°1"
    assert_selector "h1.ps-title", text: "PRÉPARE DEVOIRS N°1"
    assert_selector ".ps-exercise", count: 4
    assert_selector "fieldset[disabled]", count: 4
    assert_no_button "Vérifier ma réponse"
    assert_no_button "Indice"

    click_link "Commencer Prépare devoirs"
    assert_current_path fill_course_sheet_path(@course.slug, "sujet-#{@subject.position}")
    within(frame(@exercises.first)) do
      click_button "A."
      click_button "Vérifier ma réponse"
    end

    assert_selector "#session_grade"
    click_link "Continuer les exercices"
    assert_current_path fill_course_sheet_path(@course.slug, "sujet-#{@subject.position}")
    within(frame(@exercises.first)) { assert_selector ".ps-status", text: "Réussi" }

    visit course_path(@course.slug)
    assert_selector "#sujet-#{@subject.position} .ps-card-meta", text: "1 / 4 exercice réussi"
    find("a.ps-card#sujet-#{@subject.position}").click
    assert_link "Continuer Prépare devoirs"
  end

  test "on a 390 px screen the reading page does not overflow and « Commencer » is 48 px high" do
    with_mobile_viewport do
      visit course_sheet_path(@course.slug, "sujet-#{@subject.position}")

      assert_selector "a.ps-start"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"), :<=, 0
      assert_operator find("a.ps-start").rect.height, :>=, 48
    end
  end
end
