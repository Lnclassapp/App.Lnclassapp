require "test_helper"

# medailles-enseignant (UDR médailles) : le suivi d'un devoir ne dit plus « Copies rendues » ni notes ; les élèves sont en ordre alphabétique.
class Classroom::AssignmentFollowUpNoCopiesTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom
    @teacher = create_teacher(classrooms: [ @classroom ])
    @exercise = create_exercise(essential: create_essential(course: create_course(level: @classroom.level, series: @classroom.series)),
                                title: "Exercice notion 2")
    @assignment = create_assignment(classroom: @classroom, assignable: @exercise, by: @teacher, due_on: Date.current + 3)
    sign_in_as @teacher
  end

  test "no « Copies rendues » section, no grade on 20 or percentage: the medal alone, students in alphabetical order" do
    [ [ "Zoé", "Achi", 95 ], [ "Awa", "Bamba", 40 ] ].each do |first, last, score|
      student = create_student(classroom: @classroom, first_name: first, last_name: last)
      create_exercise_session(student: student, exercise: @exercise, status: "completed", score_percent: score,
                              completed_at: 1.day.ago, classroom_assignment: @assignment)
    end

    get classroom_assignment_path(@classroom.public_id, @assignment.public_id)

    assert_response :success
    assert_select "#follow_up_copies", 0
    assert_select "#comprehension_panel ul li a[data-turbo-frame=_top]" do |links|
      assert_equal [ "Zoé Achi", "Awa Bamba" ], links.map(&:text)
    end
    assert_select "#comprehension_panel", text: %r{/20|\d+ ?%|Copies rendues|meilleure note}, count: 0
  end
end
