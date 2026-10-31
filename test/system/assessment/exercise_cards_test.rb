require "application_system_test_case"

# UDR-0145 — CA-1, CA-3 : « Ma classe » montre des cartes d'exercice ; CA-8 : l'écran d'un
# exercice montre une carte par question avec son format. Toute la carte est le lien.
class Assessment::ExerciseCardsTest < ApplicationSystemTestCase
  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique"),
                                  level: create_level(name: "Tle"), series: create_series(name: "D"))
    @student = create_student(classroom: @classroom, first_name: "Aya")
    create_teacher(school: @classroom.school, classrooms: [ @classroom ])
    course = create_course(name: "Génétique", material: create_material(name: "SVT", category: "science"),
                           level: @classroom.level, series: @classroom.series)
    essential = create_essential(course:)
    @todo = create_exercise(essential:, title: "La fixation du CO2", exercise_type: "fixation", questions: 0)
    create_kind_question(exercise: @todo, question_type: "matching", content: "Relie.", answers: [ %w[G1 D1], %w[G2 D2], %w[G3 D3] ])
    question = @todo.questions.create!(position: 2, content: "Lesquelles ?", question_type: "multiple_correct_3")
    4.times { |rank| question.answers.create!(position: rank + 1, content: "Choix #{rank + 1}", correct: rank < 3) }
    create_assignment(classroom: @classroom, assignable: @todo)
    done = create_exercise(essential:, title: "Le bilan")
    @copy = create_exercise_session(student: @student, exercise: done, status: "completed", score_percent: 80)
    sign_in_as @student
  end

  # Un vrai clic à la position du verbe : le lien étiré le reçoit (Selenium refuse de cliquer l'élément lui-même, qu'il recouvre).
  def click_at_center(element) = page.driver.browser.action.move_to(element.native).click.perform

  # prepare-interros-cahier, Lot F : l'exercice à faire n'est plus une carte mais une feuille (CA-13) ; la carte traitée reste.
  test "CA-1, CA-3 : « Ma classe » : l'exercice à faire est une feuille à rendre, la carte traitée dit 16/20 et Voir ma copie" do
    visit student_classroom_path

    within "#sheet-exercise-#{@todo.public_id}" do
      assert_text "Exercice 1"
      assert_button "Rendre à l'enseignant"
    end

    within "#student_classroom_treated" do
      assert_text "16/20"
      click_at_center(find("span", text: "Voir ma copie"))
    end
    assert_current_path exercise_session_result_path(@copy.public_id)
  end

  test "CA-8 : l'écran d'un exercice : une carte numérotée par question, avec son format" do
    visit exercise_path(@todo.public_id)

    assert_selector "#sheet-question-1-format", text: "Relier"
    assert_selector "#sheet-question-2-format", text: "Plusieurs réponses"
    assert_no_text "3 propositions correctes"
  end
end
