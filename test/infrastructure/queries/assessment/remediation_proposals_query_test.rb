require "test_helper"

module Queries
  module Assessment
    # suivi-classe-lecon CA-7, CA-9, CA-10: the exercise offered to a student for each of their pending sheets: the
    # fixation first, never the one just failed unless it is the only one; nil exercise when the sheet has none left.
    class RemediationProposalsQueryTest < ActiveSupport::TestCase
      setup do
        @course = create_course(name: "Géométrie")
        @thales = create_essential(course: @course, name: "Théorème de Thalès")
        @student = create_student_for(@course)
        @e1 = create_exercise(essential: @thales, questions: 1, exercise_type: "evaluation")
        @e2 = create_exercise(essential: @thales, questions: 1, exercise_type: "evaluation")
        @e3 = create_exercise(essential: @thales, questions: 1, exercise_type: "fixation")
      end

      def open_gap(from: @e1, essential: @thales)
        session = create_exercise_session(student: @student, exercise: from, status: "completed", score_percent: 20)
        create_gap(student: @student, essential:, source_session: session)
      end

      def call(**) = RemediationProposalsQuery.new.call(student_id: @student.id, **)

      test "CA-7: the fixation exercise of the sheet, not the failed one" do
        open_gap

        proposal = call.fetch(@thales.slug)

        assert_equal [ @thales.slug, @course.slug, @e3.public_id ], [ proposal.essential_slug, proposal.course_slug, proposal.exercise_public_id ]
      end

      test "without fixation, the first other exercise by position" do
        @e3.update!(status: "archived", archived_at: Time.current)
        open_gap

        assert_equal @e2.public_id, call.fetch(@thales.slug).exercise_public_id
      end

      test "CA-9: the only exercise of the sheet is the failed one, and it is offered" do
        @e2.update!(status: "archived", archived_at: Time.current)
        @e3.update!(status: "archived", archived_at: Time.current)
        open_gap

        assert_equal @e1.public_id, call.fetch(@thales.slug).exercise_public_id
      end

      test "CA-10: no published exercise left, the proposal names the sheet only" do
        open_gap
        [ @e1, @e2, @e3 ].each { it.update!(status: "archived", archived_at: Time.current) }

        proposal = call.fetch(@thales.slug)

        assert_nil proposal.exercise_public_id
        assert_equal @course.slug, proposal.course_slug
      end

      test "CA-11: a lifted gap proposes nothing" do
        session = create_exercise_session(student: @student, exercise: @e1, status: "completed", score_percent: 20)
        create_gap(student: @student, essential: @thales, status: "remediated", source_session: session)

        assert_empty call
      end

      test "another student's gap is not read, and essential_slugs narrows the result" do
        open_gap
        other = create_essential(course: @course, name: "Pythagore")
        create_exercise(essential: other, questions: 1)
        open_gap(from: other.exercises.first, essential: other)

        assert_equal [ @thales.slug, other.slug ].sort, call.keys.sort
        assert_equal [ other.slug ], call(essential_slugs: [ other.slug ]).keys
        assert_empty RemediationProposalsQuery.new.call(student_id: create_student.id)
      end

      test "two queries however many pending sheets" do
        open_gap
        other = create_essential(course: @course, name: "Pythagore")
        open_gap(from: create_exercise(essential: other, questions: 1), essential: other)

        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { call }

        assert_operator count, :<=, 2
      end
    end
  end
end
