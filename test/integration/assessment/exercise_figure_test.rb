require "test_helper"

# Refonte contenus maths, Lot D (CA-13) : la figure citée par un exercice s'affiche sous son sujet, sur la page de l'exercice
# et sur la copie en cours ; sans figure (ou clé introuvable), aucun emplacement vide.
class Assessment::ExerciseFigureTest < ActionDispatch::IntegrationTest
  setup do
    @exercise = create_exercise(title: "Thalès", questions: 1)
    @course = @exercise.course
    @student = create_student_for(@course)
    @session = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student
  end

  def cite(key)
    @course.update!(figures: [ revision_figure ])
    @exercise.update!(figure_key: key)
  end

  test "la page de l'exercice affiche la figure sous le sujet, cadre application" do
    cite("triangle-thales")
    get exercise_path(@exercise.public_id)

    assert_response :success
    assert_select "#exercise-sheet figure[data-controller=figure][data-figure-kind-value=geometry]", 1
    assert_select "#exercise-sheet figure.rounded-xl", 1
    assert_select "#exercise-sheet figcaption", text: /triangle ABC rectangle en A/
  end

  test "la copie en cours affiche la figure sous le sujet" do
    cite("triangle-thales")
    get exercise_session_path(@session.public_id)

    assert_response :success
    assert_select "#copy-statement figure[data-controller=figure]", 1
    assert_select "#copy-statement figure.rounded-xl", 1
  end

  test "sans figure citée, aucun emplacement de figure" do
    get exercise_path(@exercise.public_id)
    assert_select "figure", 0
    get exercise_session_path(@session.public_id)
    assert_select "figure", 0
  end

  test "une clé introuvable dans la leçon ne casse rien et n'affiche rien" do
    cite("inconnue")
    get exercise_path(@exercise.public_id)
    assert_response :success
    assert_select "figure", 0
    get exercise_session_path(@session.public_id)
    assert_response :success
    assert_select "figure", 0
  end
end
