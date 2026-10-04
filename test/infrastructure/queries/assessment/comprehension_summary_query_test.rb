require "test_helper"

# ADR-0079 §4.2 à §4.4, UDR-0072 §3.4 : le résumé d'un exercice assigné, au bord bas de sa ligne sur la page classe. La
# catégorie dominante des meilleurs scores, lisible à partir de 5 élèves ; les badges comptés par palier sur le meilleur
# score, les quatre paliers toujours présents. Une seule lecture, celle d'AssignmentScores.
module Queries
  module Assessment
    class ComprehensionSummaryQueryTest < ActiveSupport::TestCase
      NO_BADGE = { bronze: 0, silver: 0, gold: 0, diamond: 0 }.freeze

      setup do
        @school = create_school
        @classroom = create_classroom(school: @school)
        @exercise = create_exercise
        @assignment = create_assignment(classroom: @classroom, assignable: @exercise)
      end

      def hand_in(student, score_percent, assignment: @assignment, **attributes)
        create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed",
                                score_percent:, classroom_assignment: assignment, **attributes)
      end

      def summaries(assignment_ids = [ @assignment.id ])
        ComprehensionSummaryQuery.for(classroom_id: @classroom.id, assignment_ids:)
      end

      def summary = summaries.fetch(@assignment.id)

      test "PRD: best scores 100, 85, 72, 65, 40 and 30 give one badge of each level and an « acquired » circle" do
        students = Array.new(6) { create_student(classroom: @classroom) }
        19.times { create_student(classroom: @classroom) }
        hand_in(students[0], 100)
        hand_in(students[1], 40, completed_at: 2.days.ago)
        hand_in(students[1], 85, completed_at: 1.day.ago)
        hand_in(students[2], 72, completed_at: 2.days.ago)
        hand_in(students[2], 30, completed_at: 1.day.ago)
        [ 65, 40, 30 ].each_with_index { |score, index| hand_in(students[3 + index], score) }

        assert_equal ComprehensionSummaryQuery::Summary.new(category: :acquired,
                                                            badge_counts: { bronze: 1, silver: 1, gold: 1, diamond: 1 }), summary
      end

      test "under 5 students the circle is not readable yet, the badges are still counted" do
        4.times { hand_in(create_student(classroom: @classroom), 90) }

        assert_equal ComprehensionSummaryQuery::Summary.new(category: nil, badge_counts: NO_BADGE.merge(gold: 4)), summary
      end

      test "from 5 students, the dominant category; the most fragile one on a tie" do
        [ 45, 30, 60, 55, 90 ].each { hand_in(create_student(classroom: @classroom), it) }

        assert_equal :struggling, summary.category
        assert_equal NO_BADGE.merge(bronze: 2, gold: 1), summary.badge_counts
      end

      test "an assignment nobody did has a grey circle and four empty levels; no assignment, no entry" do
        nobody = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential))
        hand_in(create_student(classroom: @classroom), 70)

        result = summaries([ @assignment.id, nobody.id ])

        assert_equal [ @assignment.id, nobody.id ], result.keys
        assert_equal ComprehensionSummaryQuery::Summary.new(category: nil, badge_counts: NO_BADGE), result.fetch(nobody.id)
        assert_equal({}, summaries([]))
      end

      test "another classroom, another assignment, a remediation, a started session, a student gone or anonymized do not count" do
        student = create_student(classroom: @classroom)
        hand_in(student, 100, gap: create_gap(student:, essential: @exercise.essential))
        hand_in(student, 100, assignment: create_assignment(classroom: create_classroom(school: @school), assignable: @exercise))
        hand_in(student, 100, assignment: create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential)))
        create_exercise_session(student:, exercise: @exercise, classroom_assignment: @assignment)
        gone = create_student(classroom: @classroom)
        hand_in(gone, 100)
        Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
        anonymized = create_student(classroom: @classroom)
        hand_in(anonymized, 100)
        anonymized.update_columns(anonymized_at: Time.current)
        hand_in(create_student(classroom: @classroom), 55)

        assert_equal ComprehensionSummaryQuery::Summary.new(category: nil, badge_counts: NO_BADGE.merge(bronze: 1)), summary
      end

      test "one read whatever the number of assignments" do
        hand_in(create_student(classroom: @classroom), 70)
        one = count_queries { summaries }
        others = Array.new(3) { create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential)) }
        others.each { hand_in(create_student(classroom: @classroom), 80, assignment: it) }

        assert_equal 1, one
        assert_equal one, count_queries { summaries([ @assignment.id, *others.map(&:id) ]) }
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
