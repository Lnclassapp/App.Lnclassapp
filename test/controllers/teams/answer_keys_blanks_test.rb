require "test_helper"

# ADR questions à plusieurs cases §4, UDR je-m-entraine §3.9 : le corrigé de l'équipe montre chaque case avec ses réponses
# acceptées, et l'indice de la question.
class Teams::AnswerKeysBlanksTest < ActionDispatch::IntegrationTest
  test "le corrigé montre chaque case, ses réponses acceptées et l'indice" do
    course = create_course(name: "Thalès", status: "draft")
    exercise = create_exercise(essential: create_essential(course:, name: "Thalès", position: 1, status: "draft"), questions: 0, status: "draft")
    question = exercise.questions.create!(position: 1, content: "AN (cm) = ___  MN (cm) = ___", question_type: "numeric", unit: "cm", hint: "Pense au coefficient.")
    [ "3", "4,5" ].each_with_index { |value, blank| question.answers.create!(position: blank + 1, content: value, correct: true, blank:) }
    sign_in_as create_team_member

    get answer_key_teams_course_path(course.slug)

    assert_response :success
    assert_select "section#exercise-#{exercise.public_id} ol ol > li", 2
    assert_select "section#exercise-#{exercise.public_id}", text: /Case 1 de la question 1/
    assert_select "section#exercise-#{exercise.public_id}", text: /Case 2 de la question 1/
    assert_select "section#exercise-#{exercise.public_id}", text: /4,5 cm/
    assert_select "section#exercise-#{exercise.public_id}", text: /Indice : Pense au coefficient\./
  end

  test "une question à une case garde le corrigé d'avant, sans indice quand il n'y en a pas" do
    course = create_course(name: "Racines", status: "draft")
    exercise = create_exercise(essential: create_essential(course:, name: "R", position: 1, status: "draft"), questions: 0, status: "draft")
    question = exercise.questions.create!(position: 1, content: "Combien ?", question_type: "numeric")
    question.answers.create!(position: 1, content: "7", correct: true)
    sign_in_as create_team_member

    get answer_key_teams_course_path(course.slug)

    assert_select "section#exercise-#{exercise.public_id}", text: /Valeur attendue : 7/
    assert_select "section#exercise-#{exercise.public_id}", text: /Case 1/, count: 0
    assert_select "section#exercise-#{exercise.public_id}", text: /Indice/, count: 0
  end
end
