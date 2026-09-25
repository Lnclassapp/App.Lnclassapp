require "test_helper"

module Entities
  module Assessment
    class ExerciseSessionTest < ActiveSupport::TestCase
      def build(**overrides)
        ExerciseSession.new(id: 1, public_id: "s", student_id: 2, exercise_id: 3, status: "started", question_count: 4,
                            answered_count: 3, correct_count: 2, progress_percent: 75, score_percent: nil, kind: "standard",
                            knowledge_gap_id: nil, classroom_assignment_id: nil, started_at: Time.current, completed_at: nil,
                            **overrides)
      end

      test "complète quand toutes les questions sont répondues" do
        assert_not build.complete?
        assert build(answered_count: 4).complete?
      end

      test "statut et type" do
        assert build.started?
        assert_not build.completed?
        assert build(status: "completed").completed?
        assert build(kind: "remediation").remediation?
        assert_not build.remediation?
        assert_equal %w[started completed abandoned], ExerciseSession::STATUSES
        assert_equal %w[standard remediation], ExerciseSession::KINDS
      end
    end
  end
end
