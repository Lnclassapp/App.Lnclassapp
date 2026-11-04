require "application_system_test_case"

# sujet-avant-de-commencer, Lot B (UDR feuilles-en-cases-lues-avant-de-commencer) : « Ma classe » montre une case par devoir reçu ; la case
# ouvre le sujet en lecture ; « Commencer » ouvre la feuille avec « Rendre à l'enseignant » ; le résultat ramène à la feuille du devoir.
class Classroom::AssignedSheetCardsTest < ApplicationSystemTestCase
  setup do
    @course = create_course(name: "Thalès")
    @notion = create_essential(course: @course, name: "La propriété de Thalès", position: 1)
    @classroom = create_classroom(level: @course.level, series: @course.series, name: "3e 1")
    @student = create_student(classroom: @classroom)
    @teacher = create_teacher(classrooms: [ @classroom ])
    @devoir = Array.new(3) { |index| create_exercise(essential: @notion, title: "Devoir #{index + 1}", questions: 1) }
    @devoir.each do |exercise|
      create_assignment(classroom: @classroom, assignable: exercise, by: @teacher, batch_public_id: "BATCHDEVOIRXXX", assigned_at: 2.hours.ago,
                        due_on: Date.current + 2)
    end
    @alone = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @notion, title: "Interro", questions: 1),
                               by: @teacher, assigned_at: 1.hour.ago)
    @sheet = "devoir-batchdevoirxxx"
    sign_in_as @student
  end

  def frame(exercise) = "#sheet-exercise-#{exercise.public_id}"

  test "case du devoir, lecture, Commencer, Rendre à l'enseignant, retour à la feuille du devoir, puis « Rendu » sur la case" do
    visit student_classroom_path
    assert_selector "#student_classroom_assigned a.ps-card", count: 2
    assert_no_selector "#student_classroom_assigned .ps-sheet"
    assert_no_button "Rendre à l'enseignant"
    assert_selector "a.ps-card:first-child .ps-card-kind", text: "PRÉPARE INTERROS N°1"
    assert_selector "a.ps-card##{@sheet}", text: /À rendre le/

    find("a.ps-card##{@sheet}").click
    assert_current_path student_assigned_sheet_path(@sheet)
    assert_selector "h1.ps-title", text: "PRÉPARE DEVOIRS N°1"
    assert_selector ".ps-exercise", count: 3
    assert_selector "fieldset[disabled]", count: 3
    assert_no_button "Rendre à l'enseignant"

    click_link "Commencer Prépare devoirs"
    assert_current_path fill_student_assigned_sheet_path(@sheet)
    first = @devoir.first
    within(frame(first)) do
      click_button "A."
      click_button "Rendre à l'enseignant"
    end

    assert_selector "#session_grade", text: "20/20"
    click_link "Reprendre le devoir"
    assert_current_path fill_student_assigned_sheet_path(@sheet)
    within(frame(first)) { assert_selector ".ps-status", text: "Réussi" }

    visit student_assigned_sheet_path(@sheet)
    assert_link "Continuer Prépare devoirs"
    visit student_classroom_path
    assert_selector "a.ps-card##{@sheet} .ps-card-meta", text: "1 / 3 exercice réussi"
  end

  test "on a 390 px screen the cards and the reading page do not overflow and « Commencer » is 48 px high" do
    with_mobile_viewport do
      visit student_classroom_path
      assert_selector "a.ps-card", count: 2
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"), :<=, 0

      visit student_assigned_sheet_path(@sheet)
      assert_operator page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"), :<=, 0
      assert_operator find("a.ps-start").rect.height, :>=, 48
    end
  end
end
