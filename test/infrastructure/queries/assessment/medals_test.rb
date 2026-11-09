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

      test "the distribution of a assignment counts present students only, per level, and reads nothing from another class" do
        other = create_student(classroom: @class_a)
        gone = create_student(classroom: @class_a)
        [ [ @student, "gold" ], [ other, "bronze" ], [ gone, "bronze" ] ].each do |student, level|
          session = create_exercise_session(student:, exercise: @exercise, status: "completed", classroom_assignment: @assignment_a)
          create_badge(student:, exercise: @exercise, level:, session:)
        end
        Orm::ClassroomStudent.where(student_id: gone.id).update_all(left_at: 1.minute.ago)

        assert_equal({ @assignment_a.id => { gold: 1, bronze: 1 } }, Medals.distribution_by_assignment(assignment_ids: [ @assignment_a.id ]))
        assert_equal({}, Medals.distribution_by_assignment(assignment_ids: [ @assignment_b.id ]))
        elsewhere = create_exercise_session(student: other, exercise: create_exercise, status: "completed", classroom_assignment: @assignment_b)
        create_badge(student: other, exercise: elsewhere.exercise, level: "diamond", session: elsewhere)
        assert_equal({ @assignment_a.id => { gold: 1, bronze: 1 } }, Medals.distribution_by_assignment(assignment_ids: [ @assignment_a.id ]))
        assert_equal({}, Medals.distribution_by_assignment(assignment_ids: []))
      end

      test "a medal raised outside the assignment does not hide the one its own treated copy earned" do
        session = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 72, classroom_assignment: @assignment_a)
        create_attempt(session:)
        solo = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 100, classroom_assignment: nil)
        create_badge(student: @student, exercise: @exercise, level: "diamond", session: solo)

        assert_equal({ @assignment_a.id => { @student.id => :silver } }, Medals.by_assignment(assignment_ids: [ @assignment_a.id ]))
        assert_equal({ @assignment_a.id => { silver: 1 } }, Medals.distribution_by_assignment(assignment_ids: [ @assignment_a.id ]))
        assert_equal({ @class_a.id => { @student.id => { silver: 1 } } }, Medals.by_classroom(classroom_ids: [ @class_a.id ]))
        assert_equal({ @student.id => { silver: 1 } }, Medals.by_student_in_school(school_id: @school.id, student_ids: [ @student.id ]))
      end

      test "an empty copy gives no medal" do
        create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 0, classroom_assignment: @assignment_a)

        assert_equal({}, Medals.by_assignment(assignment_ids: [ @assignment_a.id ]))
      end
    end
  end
end
