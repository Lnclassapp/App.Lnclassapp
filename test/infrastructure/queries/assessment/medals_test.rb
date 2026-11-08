require "test_helper"

# ADR-0097 §4.5 : une médaille ne se lit dans une classe que si la session qui l'a enregistrée appartient à une de ses assignations.
module Queries
  module Assessment
    class MedalsTest < ActiveSupport::TestCase
      setup do
        @school = create_school
        @class_a = create_classroom(school: @school)
        @class_b = create_classroom(school: @school)
        @exercise = create_exercise
        @assignment_a = create_assignment(classroom: @class_a, assignable: @exercise)
        @assignment_b = create_assignment(classroom: @class_b, assignable: @exercise)
        @student = create_student(classroom: @class_a)
        Orm::ClassroomStudent.create!(classroom: @class_b, student: @student, primary: false, joined_at: Time.current, joined_via: "standard")
      end

      test "a gold won by a session of the assignment of class B is not read from class A" do
        session = create_exercise_session(student: @student, exercise: @exercise, status: "completed", classroom_assignment: @assignment_b)
        create_badge(student: @student, exercise: @exercise, level: "gold", session:)

        assert_equal({}, Medals.by_assignment(assignment_ids: [ @assignment_a.id ]))
        assert_equal({ @assignment_b.id => { @student.id => :gold } }, Medals.by_assignment(assignment_ids: [ @assignment_b.id ]))
      end

      test "a medal won by a solo session (no assignment) is read from no assignment" do
        session = create_exercise_session(student: @student, exercise: @exercise, status: "completed", classroom_assignment: nil)
        create_badge(student: @student, exercise: @exercise, level: "gold", session:)

        assert_equal({}, Medals.by_assignment(assignment_ids: [ @assignment_a.id, @assignment_b.id ]))
      end
    end
  end
end
