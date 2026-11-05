require "test_helper"

# sujet-avant-de-commencer, Lot B (UDR feuilles-en-cases-lues-avant-de-commencer §3) : l'enseignant lit, depuis sa classe, le sujet d'une
# feuille de la leçon ; ses bascules d'envoi sont celles de cette classe seulement ; mêmes refus que la page de la leçon dans la classe.
class Classroom::ClassroomPrepareSheetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Thalès")
    @notion = create_essential(course: @course, name: "Réciproque", position: 1)
    @ex = create_exercise(essential: @notion, title: "Exercice notion")
    @subject = create_subject(course: @course, title: "Sujet 1", notions: "Thalès")
    @devoir = create_exercise(subject: @subject, course: @course, title: "Devoir 1", position: 40)
    @classroom = create_classroom(name: "3e 1", level: @course.level, series: @course.series)
    @teacher = create_teacher(classrooms: [ @classroom ])
    @sheet = "notion-#{@notion.slug}"
  end

  def toggle_id(classroom, exercise) = "assignment_#{classroom.public_id}_Exercise_#{exercise.public_id}"

  test "the teacher reads the sheet in her classroom: toggles of this classroom only, the batch bar, no « Commencer »" do
    other = create_classroom(name: "3e 2", level: @course.level, series: @course.series, school: @classroom.school)
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom: other)
    sign_in_as @teacher

    get classroom_course_sheet_path(@classroom.public_id, @course.slug, @sheet)

    assert_response :success
    assert_select "h1.ps-paper-heading", text: /\AÉPREUVE DE /
    assert_select ".ps-paper-name", text: /Prépare interros n°1/
    assert_select "section.ps-paper-exercise#sheet-exercise-#{@ex.public_id}"
    assert_select "##{toggle_id(@classroom, @ex)}"
    assert_select "[id^='assignment_#{other.public_id}']", 0
    assert_select "#sheet-batch-bar"
    assert_select "a.ps-start", 0
    assert_select "a[href=?]", classroom_course_path(@classroom.public_id, @course.slug, anchor: @sheet), text: /Thalès/
  end

  # suivi-classe-lecon (ADR lecture-de-la-classe-par-la-direction, CA-12, CA-13) : la direction lit la réussite, sans agir ; ailleurs, 404.
  test "the school admin of the same school reads the class success, without « Choisir » nor toggle; another school gets 404" do
    sign_in_as create_school_admin(school: @classroom.school)
    get classroom_course_sheet_path(@classroom.public_id, @course.slug, @sheet)

    assert_response :success
    assert_select "#sheet-success-#{@ex.public_id}"
    assert_select "##{toggle_id(@classroom, @ex)}", 0
    assert_select "[data-batch-choice], .ps-btn--choose, #sheet-batch-bar", 0

    sign_in_as create_school_admin(school: create_school(name: "Autre lycée"))
    get classroom_course_sheet_path(@classroom.public_id, @course.slug, @sheet)

    assert_response :not_found
  end

  test "a subject is read the same way" do
    sign_in_as @teacher

    get classroom_course_sheet_path(@classroom.public_id, @course.slug, "sujet-#{@subject.position}")

    assert_response :success
    assert_select "h1.ps-paper-heading", text: /\AÉPREUVE DE /
    assert_select ".ps-paper-name", text: /Prépare devoirs n°1/
    assert_select "##{toggle_id(@classroom, @devoir)}"
  end

  test "the team reads the sheet with the toggle of this classroom only (suivi-classe-lecon CA-16)" do
    sign_in_as create_team_member

    get classroom_course_sheet_path(@classroom.public_id, @course.slug, @sheet)

    assert_response :success
    assert_select "[id^=assignment_]", 1
    assert_select "[id^=assignment_#{@classroom.public_id}_]", 1
    # sujet-comme-une-epreuve : l'équipe ne voit plus « Publié » ; seul un brouillon porte sa mention (sheet_paper_test).
    assert_select ".ps-paper-exercise", 1
    assert_select ".ps-paper-exercise-title .ps-status", 0
    assert_select "a.ps-start", 0
  end

  test "an unknown sheet goes back to the lesson of the classroom with « Cette feuille n'existe plus. »" do
    sign_in_as @teacher

    get classroom_course_sheet_path(@classroom.public_id, @course.slug, "sujet-9")

    assert_redirected_to classroom_course_path(@classroom.public_id, @course.slug)
    assert_equal 303, response.status
    assert_equal "Cette feuille n'existe plus.", flash[:alert]
  end

  test "another teacher or a student of the classroom receives 403" do
    [ create_teacher, create_student(classroom: @classroom) ].each do |user|
      sign_in_as user

      get classroom_course_sheet_path(@classroom.public_id, @course.slug, @sheet)

      assert_response :forbidden
      sign_out
    end
  end

  test "an unknown classroom or lesson, a lesson of another level: 404" do
    sign_in_as @teacher
    get classroom_course_sheet_path("inconnue", @course.slug, @sheet)
    assert_response :not_found
    get classroom_course_sheet_path(@classroom.public_id, "inconnu", @sheet)
    assert_response :not_found
    sign_out

    other_level = create_classroom(name: "6ème 1")
    sign_in_as create_teacher(classrooms: [ other_level ])
    get classroom_course_sheet_path(other_level.public_id, @course.slug, @sheet)
    assert_response :not_found
  end

  test "an archived classroom has no page, even for its teacher" do
    archived = create_classroom(status: "archived")
    sign_in_as create_teacher(classrooms: [ archived ])

    get classroom_course_sheet_path(archived.public_id, @course.slug, @sheet)

    assert_response :not_found
  end

  test "a signed-out visitor is sent to sign in" do
    get classroom_course_sheet_path(@classroom.public_id, @course.slug, @sheet)

    assert_redirected_to new_session_path
    assert_no_match "Exercice notion", response.body
  end

  test "the teacher reads under each exercise how many students of the class passed it (CA-5, CA-6)" do
    awa = create_student(classroom: @classroom)
    create_student(classroom: @classroom)
    create_exercise_session(student: awa, exercise: @ex, status: "completed", score_percent: 80)
    sign_in_as @teacher

    get classroom_course_sheet_path(@classroom.public_id, @course.slug, @sheet)

    assert_select "#sheet-success-#{@ex.public_id}", text: /1 \/ 2 élèves ont réussi/
  end

  test "an exercise nobody of the class finished reads « Pas encore fait par la classe » (CA-6)" do
    create_student(classroom: @classroom)
    sign_in_as @teacher

    get classroom_course_sheet_path(@classroom.public_id, @course.slug, @sheet)

    assert_select "#sheet-success-#{@ex.public_id}", text: "Pas encore fait par la classe"
  end
end
