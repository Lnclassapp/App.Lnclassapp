require "test_helper"

# ADR-0079 §4.1 et §4.5 : la lecture socle de la compréhension d'un exercice assigné. Seules comptent les sessions faites
# (standard, terminées) rattachées à l'assignation, d'élèves présents ; le premier essai et le meilleur, le plus récent
# à égalité, sont désignés pour les taux par question.
module Queries
  module Assessment
    class AssignmentScoresTest < ActiveSupport::TestCase
      setup do
        @school = create_school
        @classroom = create_classroom(school: @school)
        @exercise = create_exercise
        @assignment = create_assignment(classroom: @classroom, assignable: @exercise)
      end

      def hand_in(student, score_percent, at:, assignment: @assignment, **attributes)
        create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed",
                                score_percent:, classroom_assignment: assignment, completed_at: at, **attributes)
      end

      def scores(assignment_ids = [ @assignment.id ])
        AssignmentScores.for(classroom_id: @classroom.id, assignment_ids:)
      end

      test "the scores of a student in the order of completion, his first attempt and his best one" do
        student = create_student(classroom: @classroom)
        third = hand_in(student, 90, at: Time.zone.local(2026, 10, 9, 10))
        first = hand_in(student, 30, at: Time.zone.local(2026, 10, 7, 10))
        hand_in(student, 60, at: Time.zone.local(2026, 10, 8, 10))

        assert_equal({ @assignment.id => [ AssignmentScores::StudentScores.new(student_id: student.id, scores: [ 30, 60, 90 ],
                                                             first_session_id: first.id, best_session_id: third.id) ] },
                     scores)
      end

      test "on a tie of the best score, the most recent session is the best attempt; same instant, the last created" do
        student = create_student(classroom: @classroom)
        first = hand_in(student, 80, at: Time.zone.local(2026, 10, 7, 10))
        hand_in(student, 50, at: Time.zone.local(2026, 10, 8, 10))
        latest = hand_in(student, 80, at: Time.zone.local(2026, 10, 9, 10))
        twin = create_student(classroom: @classroom)
        before = hand_in(twin, 70, at: Time.zone.local(2026, 10, 9, 10))
        after = hand_in(twin, 70, at: Time.zone.local(2026, 10, 9, 10))

        rows = scores.fetch(@assignment.id).index_by(&:student_id)

        assert_equal [ [ 80, 50, 80 ], first.id, latest.id ], rows.fetch(student.id).to_h.values_at(:scores, :first_session_id, :best_session_id)
        assert_equal [ [ 70, 70 ], before.id, after.id ], rows.fetch(twin.id).to_h.values_at(:scores, :first_session_id, :best_session_id)
      end

      test "a remediation session, a session of another assignment or a started one does not count" do
        student = create_student(classroom: @classroom)
        hand_in(student, 100, at: Time.zone.local(2026, 10, 9, 10), gap: create_gap(student:, essential: @exercise.essential))
        other_classroom = create_assignment(classroom: create_classroom(school: @school), assignable: @exercise)
        hand_in(student, 100, at: Time.zone.local(2026, 10, 9, 10), assignment: other_classroom)
        create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent: 100)
        create_exercise_session(student:, exercise: @exercise, classroom_assignment: @assignment)

        assert_equal({}, scores)
      end

      test "a student who left or whose account was anonymized does not count" do
        gone = create_student(classroom: @classroom)
        hand_in(gone, 90, at: Time.zone.local(2026, 10, 9, 10))
        Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
        anonymized = create_student(classroom: @classroom)
        hand_in(anonymized, 90, at: Time.zone.local(2026, 10, 9, 10))
        anonymized.update_columns(anonymized_at: Time.current)
        present = create_student(classroom: @classroom)
        hand_in(present, 40, at: Time.zone.local(2026, 10, 9, 10))

        assert_equal [ present.id ], scores.fetch(@assignment.id).map(&:student_id)
      end

      test "an assignment nobody did is absent; no assignment, no read" do
        nobody = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential))
        hand_in(create_student(classroom: @classroom), 70, at: Time.zone.local(2026, 10, 9, 10))

        assert_equal [ @assignment.id ], scores([ @assignment.id, nobody.id ]).keys
        assert_equal({}, scores([]))
      end

      test "several assignments are read in one query, whatever the number of assignments and students" do
        hand_in(create_student(classroom: @classroom), 70, at: Time.zone.local(2026, 10, 9, 10))
        few = count_queries { scores }
        others = Array.new(3) { create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential)) }
        students = Array.new(5) { create_student(classroom: @classroom) }
        others.product(students).each_with_index { |(assignment, student), index| hand_in(student, 50 + index, at: index.hours.ago, assignment:) }
        ids = [ @assignment.id, *others.map(&:id) ]

        assert_equal 1, few
        assert_equal few, count_queries { scores(ids) }
        assert_equal [ 1, 5, 5, 5 ], ids.map { scores(ids).fetch(it).size }
      end

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end
    end
  end
end
