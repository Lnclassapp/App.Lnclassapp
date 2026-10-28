require "test_helper"

# refonte-page-lecon (CA-24): the teacher reads, in the follow-up of an assignment, what each student handed in.
class Classroom::AssignmentFollowUpCopiesTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom
    @teacher = create_teacher(classrooms: [ @classroom ])
    @course = create_course(level: @classroom.level, series: @classroom.series)
    @exercise = create_exercise(essential: create_essential(course: @course, position: 2), title: "Exercice notion 2")
    @assignment = create_assignment(classroom: @classroom, assignable: @exercise, by: @teacher, due_on: Date.current + 3)
    @student = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    [ [ 40, 2.days.ago ], [ 75, 1.day.ago ] ].each do |score_percent, completed_at|
      create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent:, completed_at:,
                              classroom_assignment: @assignment)
    end
    sign_in_as @teacher
  end

  # CA-24
  test "the follow-up gives the student's first copy, 8/20, and best grade, 15/20, after two copies" do
    get classroom_assignment_path(@classroom.public_id, @assignment.public_id)

    assert_response :success
    assert_select "#follow_up_copies li", count: 1
    assert_select "#follow_up_copies li", text: /Awa Bamba/
    assert_select "#follow_up_copies li", text: /#{Regexp.escape(I18n.t("classroom.assignment_follow_ups.show.copy_summary", first: "8/20", best: "15/20"))}/
    assert_select "#follow_up_copies a[href='#{classroom_student_path(@classroom.public_id, @student.public_id)}']"
  end

  test "a student who handed nothing in has no line in the copies" do
    create_student(classroom: @classroom, first_name: "Zoé", last_name: "Pas-Encore")

    get classroom_assignment_path(@classroom.public_id, @assignment.public_id)

    assert_select "#follow_up_copies li", text: /Pas-Encore/, count: 0
  end

  test "an exercise of the whole lesson has its follow-up too" do
    wide = create_lesson_wide_exercise(course: @course, title: "Bilan")
    assignment = create_assignment(classroom: @classroom, assignable: wide, by: @teacher, due_on: Date.current + 3)
    create_exercise_session(student: @student, exercise: wide, status: "completed", score_percent: 60, completed_at: 1.hour.ago,
                            classroom_assignment: assignment)

    get classroom_assignment_path(@classroom.public_id, assignment.public_id)

    assert_response :success
    assert_select "h1", text: "Bilan"
    assert_select "#follow_up_copies li", text: /12\/20/
  end
end
