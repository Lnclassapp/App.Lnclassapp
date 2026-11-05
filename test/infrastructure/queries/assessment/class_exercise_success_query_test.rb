require "test_helper"

module Queries
  module Assessment
    # suivi-classe-lecon, Lot B (CA-5, CA-6) : la réussite de la classe sous chaque exercice, une requête pour toute la feuille.
    class ClassExerciseSuccessQueryTest < ActiveSupport::TestCase
      setup do
        @essential = create_essential(course: create_course(name: "Thalès"), name: "Réciproque")
        @e1 = create_exercise(essential: @essential, questions: 1)
        @e2 = create_exercise(essential: @essential, questions: 1)
        @classroom = create_classroom
        @awa = create_student(classroom: @classroom)
        @koffi = create_student(classroom: @classroom)
        @ama = create_student(classroom: @classroom)
      end

      def call(classroom = @classroom, exercises = [ @e1, @e2 ])
        ClassExerciseSuccessQuery.new.call(classroom_public_id: classroom.public_id, exercise_ids: exercises.map(&:public_id))
      end

      def copy(student, exercise, score, **attributes)
        create_exercise_session(student:, exercise:, status: "completed", score_percent: score, **attributes)
      end

      test "best copy of each student, over the students present of the class (CA-5)" do
        copy(@awa, @e1, 40)
        copy(@awa, @e1, 70)
        copy(@koffi, @e1, 30)

        success = call.fetch(@e1.public_id)

        assert_equal [ 3, 1 ], [ success.present_count, success.passed_count ]
        assert success.done?
      end

      test "an exercise nobody finished is not done, even with a started copy (CA-6)" do
        create_exercise_session(student: @awa, exercise: @e2, status: "started")

        success = call.fetch(@e2.public_id)

        assert_not success.done?
        assert_equal 3, success.present_count
      end

      test "copies of any kind count, those of a student who left or of another class do not" do
        gone = create_student(classroom: @classroom)
        Orm::ClassroomStudent.find_by!(classroom_id: Orm::Classroom.find_by!(public_id: @classroom.public_id).id, student_id: gone.id).update!(left_at: Time.current)
        other = create_student(classroom: create_classroom)
        copy(gone, @e1, 90)
        copy(other, @e1, 90)

        success = call.fetch(@e1.public_id)

        assert_equal [ 3, 0 ], [ success.present_count, success.passed_count ]
        assert_not success.done?
      end

      test "one query set for the whole sheet" do
        copy(@awa, @e1, 80)
        queries = []
        counter = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { call }

        assert_operator queries.size, :<=, 3
      end

      test "no exercise, no query" do
        assert_equal({}, call(@classroom, []))
      end
    end
  end
end
