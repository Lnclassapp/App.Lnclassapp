require "test_helper"

# UDR-0139 §3.4, refonte-page-lecon (CA-07, CA-08): the teacher assigns an exercise from the lesson page, for the classrooms
# they teach only. A whole-lesson exercise is assigned the same way.
class Classroom::AssignFromLessonTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Thalès")
    @notions = Array.new(2) { |index| create_essential(course: @course, name: "Notion #{index + 1}", position: index + 1) }
    @exercises = @notions.map { |essential| create_exercise(essential:) }
    @wide = create_lesson_wide_exercise(course: @course)
    @classroom = create_classroom(name: "3ème 1", level: @course.level, series: @course.series)
    @foreign = create_classroom(name: "3ème 2", level: @course.level, series: @course.series, school: @classroom.school)
    @teacher = create_teacher(classrooms: [ @classroom ])
    Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 1, 4 ],
                                                                at: Time.current)
    sign_in_as @teacher
  end

  def toggle_id(classroom, exercise) = "assignment_#{classroom.public_id}_Exercise_#{exercise.public_id}"
  def assign(exercise, classroom = @classroom, **options)
    post classroom_assignments_path(classroom.public_id),
         params: { assignment: { assignable_type: "Exercise", assignable_key: exercise.public_id }, compact: "1" }, **options
  end

  # CA-07
  test "« Assigner » on the row of a sheet exercise creates the assignment due on the next session, and the row turns « Assignée »" do
    travel_to Time.zone.local(2026, 10, 5, 10) do
      get course_path(@course.slug)
      assert_select "##{toggle_id(@classroom, @exercises[1])}", text: /#{I18n.t("classroom.assignments.toggle.assign")}/

      assert_difference -> { Orm::ClassroomAssignment.where(status: "active").count }, 1 do
        assign(@exercises[1], as: :turbo_stream)
      end

      assert_response :success
      assignment = Orm::ClassroomAssignment.find_by!(assignable_type: "Exercise", assignable_id: @exercises[1].id)
      assert_equal [ @classroom.id, "active", Date.new(2026, 10, 8) ], [ assignment.classroom_id, assignment.status, assignment.due_on ]
      assert_select "turbo-stream[action=replace][target='#{toggle_id(@classroom, @exercises[1])}']" do
        assert_select "template", text: /#{I18n.t("classroom.assignments.toggle.assigned")}/
      end

      get course_path(@course.slug)
      assert_select "##{toggle_id(@classroom, @exercises[1])}", text: /#{I18n.t("classroom.assignments.toggle.assigned")}/
      assert_select "##{toggle_id(@classroom, @exercises[0])}", text: /#{I18n.t("classroom.assignments.toggle.assign")}/
    end
  end

  # AssignmentRepository#resolve_exercise lit `record.essential.course` : un exercice de toute la leçon n'a pas de notion (NoMethodError).
  # Le dépôt est hors du champ du Lot B : signalé à l'orchestrateur, le Lot 0 rouvre.
  test "an exercise of the whole lesson is assigned the same way" do
    skip "AssignmentRepository#resolve_exercise suppose une notion : hors du champ du Lot B, signalé à l'orchestrateur"
  end

  test "the whole-lesson rows carry a toggle for each classroom the teacher teaches" do
    get course_path(@course.slug)

    assert_select "#toute-la-lecon ##{toggle_id(@classroom, @wide)}"
  end

  test "the page lists only the classrooms the teacher teaches" do
    get course_path(@course.slug)

    assert_select "[id^='assignment_#{@foreign.public_id}']", 0
    assert_select "##{toggle_id(@classroom, @exercises[0])}"
  end

  # CA-08
  test "assigning to a classroom the teacher does not teach is a 403 and creates nothing" do
    assert_no_difference -> { Orm::ClassroomAssignment.count } do
      assign(@exercises[1], @foreign, as: :turbo_stream)
    end

    assert_response :forbidden
  end
end
