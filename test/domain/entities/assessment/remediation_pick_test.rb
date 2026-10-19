require "test_helper"

module Entities
  module Assessment
    # ADR-0101 §4.2: the exercise offered to lift a pending sheet. Another exercise than the failed one, a « fixation »
    # first, then by position; the failed exercise only when the sheet has nothing else; nil without exercise.
    class RemediationPickTest < ActiveSupport::TestCase
      Candidate = Data.define(:id, :exercise_type)

      def pick(source, *exercises) = RemediationPick.call(exercises:, source_exercise_id: source)

      def evaluation(id) = Candidate.new(id:, exercise_type: "evaluation")
      def fixation(id) = Candidate.new(id:, exercise_type: "fixation")

      test "a fixation other than the failed exercise wins over an earlier evaluation" do
        assert_equal 3, pick(1, evaluation(1), evaluation(2), fixation(3)).id
      end

      test "without fixation, the first other exercise by position" do
        assert_equal 2, pick(1, evaluation(1), evaluation(2), evaluation(4)).id
        assert_equal 1, pick(2, evaluation(1), evaluation(2)).id
      end

      test "a failed fixation is set aside for another exercise" do
        assert_equal 2, pick(1, fixation(1), evaluation(2)).id
        assert_equal 3, pick(1, fixation(1), evaluation(2), fixation(3)).id
      end

      test "the failed exercise alone is offered again" do
        assert_equal 1, pick(1, evaluation(1)).id
      end

      test "an unknown source (exercise archived since): the fixation, else the first exercise" do
        assert_equal 2, pick(9, evaluation(1), fixation(2)).id
        assert_equal 1, pick(nil, evaluation(1), evaluation(2)).id
      end

      test "no exercise: nil" do
        assert_nil pick(1)
      end
    end
  end
end
