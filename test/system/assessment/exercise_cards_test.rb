require "application_system_test_case"

# UDR-XXXX-exercices-et-questions-en-cartes — CA-1, CA-3 : « Ma classe » montre des cartes d'exercice ; CA-8 : l'écran d'un
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
    create_exercise_session(student: @student, exercise: done, status: "completed", score_percent: 80)
    sign_in_as @student
  end

  test "CA-1, CA-3 : « Ma classe » : la carte à faire dit Commencer, la carte traitée dit 16/20 et Voir ma copie" do
    visit student_classroom_path

    within "#exercise-#{@todo.public_id}" do
      assert_text "La fixation du CO2"
      assert_text "SVT · Fixation"
      assert_text "Commencer"
      click_link "La fixation du CO2"
    end

    assert_selector "h1", text: "La fixation du CO2"
    visit student_classroom_path
    within "#student_classroom_treated" do
      assert_text "16/20"
      assert_text "Voir ma copie"
    end
  end

  test "CA-8 : l'écran d'un exercice : une carte numérotée par question, avec son format" do
    visit exercise_path(@todo.public_id)

    assert_selector "#sheet-question-1-format", text: "Relier"
    assert_selector "#sheet-question-2-format", text: "Plusieurs réponses"
    assert_no_text "3 propositions correctes"
  end
end
