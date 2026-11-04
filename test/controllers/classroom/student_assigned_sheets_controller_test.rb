require "test_helper"

# sujet-avant-de-commencer, Lot B (UDR feuilles-en-cases-lues-avant-de-commencer §3) : un devoir reçu se lit (champs désactivés), puis se
# remplit (« Rendre à l'enseignant ») ; jamais le devoir d'une autre classe ni d'un autre élève ; élève seulement.
class Classroom::StudentAssignedSheetsControllerTest < ActionDispatch::IntegrationTest
  BATCH = "BATCHDEVOIRXXX".freeze

  setup do
    @course = create_course(name: "Thalès")
    @notion = create_essential(course: @course, name: "La propriété de Thalès", position: 1)
    @classroom = create_classroom(level: @course.level, series: @course.series, name: "3e 1")
    @student = create_student(classroom: @classroom)
    @teacher = create_teacher(classrooms: [ @classroom ])
    @exercises = Array.new(3) { |index| create_exercise(essential: @notion, title: "Devoir #{index + 1}", questions: 1) }
    @assignments = @exercises.map do |exercise|
      create_assignment(classroom: @classroom, assignable: exercise, by: @teacher, batch_public_id: BATCH, assigned_at: 1.hour.ago, due_on: Date.current + 3)
    end
    @sheet = "devoir-#{BATCH.downcase}"
  end

  def frame(exercise) = "turbo-frame#sheet-exercise-#{exercise.public_id}"

  test "the student reads the received assignment: every exercise, disabled fields, no hand-in button, « Commencer »" do
    sign_in_as @student

    get student_assigned_sheet_path(@sheet)

    assert_response :success
    assert_select "h1.ps-title", text: "Prépare devoirs n°1"
    assert_select ".ps-sheet .ps-exercise", 3
    @exercises.each { |exercise| assert_select "#{frame(exercise)} fieldset[disabled]", 1 }
    assert_select ".ps-sheet button.ps-btn--primary", 0
    assert_select ".ps-sheet form", 0
    assert_select "a.ps-start[href=?]", fill_student_assigned_sheet_path(@sheet), text: "Commencer Prépare devoirs"
    assert_select "a[href=?]", student_classroom_path(anchor: @sheet), text: /Ma classe/
  end

  test "once an exercise is handed in, the button says « Continuer »" do
    create_exercise_session(student: @student, exercise: @exercises.first, status: "completed", classroom_assignment_id: @assignments.first.id)
    sign_in_as @student

    get student_assigned_sheet_path(@sheet)

    assert_select "a.ps-start", text: "Continuer Prépare devoirs"
  end

  test "the sheet to fill: « Rendre à l'enseignant » per exercise, back to the reading page" do
    sign_in_as @student

    get fill_student_assigned_sheet_path(@sheet)

    assert_response :success
    assert_select "button.ps-btn--primary", text: "Rendre à l'enseignant", count: 3
    assert_select "#{frame(@exercises.first)} form input[name=assignment_public_id][value=?]", @assignments.first.public_id
    assert_select "#{frame(@exercises.first)} input[name=return_to][value=class]"
    assert_select "#{frame(@exercises.first)} input[name=sheet][value=?]", @sheet
    assert_select "a[href=?]", student_assigned_sheet_path(@sheet), text: "Lire le sujet"
  end

  test "an assignment of another classroom is gone: 303 to « Ma classe » with the message, on both pages" do
    other = create_classroom(level: @course.level, series: @course.series, name: "3e 2")
    create_assignment(classroom: other, assignable: create_exercise(essential: @notion, title: "Secret"), batch_public_id: "OTHERBATCHXXXX")
    sign_in_as @student

    [ student_assigned_sheet_path("devoir-otherbatchxxxx"), fill_student_assigned_sheet_path("devoir-otherbatchxxxx"),
      student_assigned_sheet_path("sujet-9"), fill_student_assigned_sheet_path("devoir-inconnu") ].each do |path|
      get path

      assert_redirected_to student_classroom_path
      assert_equal 303, response.status
      assert_equal "Cette feuille n'existe plus.", flash[:alert]
    end
  end

  test "another student of another classroom does not see this assignment" do
    sign_in_as create_student(classroom: create_classroom(level: @course.level, series: @course.series, name: "3e 3"))

    get student_assigned_sheet_path(@sheet)

    assert_redirected_to student_classroom_path
    assert_no_match "Devoir 1", response.body
  end

  test "a teacher, the team and a visitor are refused" do
    [ @teacher, create_team_member ].each do |user|
      sign_in_as user

      get student_assigned_sheet_path(@sheet)
      assert_response :forbidden
      get fill_student_assigned_sheet_path(@sheet)
      assert_response :forbidden
      sign_out
    end

    get student_assigned_sheet_path(@sheet)
    assert_response :redirect
    assert_no_match "Devoir 1", response.body
  end

  test "the card says « Rendu » once every exercise is handed in, « À rendre le … » before" do
    sign_in_as @student
    get student_classroom_path
    due = I18n.t("classroom.student_classrooms.assigned_sheet.due_on", date: I18n.l(Date.current + 3, format: :due_long))
    assert_select "a.ps-card##{@sheet} .ps-card-meta", text: due

    @exercises.zip(@assignments) do |exercise, assignment|
      create_exercise_session(student: @student, exercise:, status: "completed", classroom_assignment_id: assignment.id)
    end
    get student_classroom_path

    assert_select "a.ps-card##{@sheet} .ps-card-meta", text: "Rendu"
    assert_select "a.ps-card##{@sheet} .ps-card-meta", text: due, count: 0
  end
end
