require "test_helper"

module Entities
  module Assessment
    class GapDecisionTest < ActiveSupport::TestCase
      def decide(score, gap, kind = "standard") = GapDecision.call(score_percent: score, pending_gap: gap, session_kind: kind)

      test "sous le seuil : ouvre ou incrémente" do
        assert_equal :open, decide(49, nil)
        assert_equal :increment, decide(0, :gap)
      end

      test "entre la réussite et le seuil de remédiation : la lacune reste en attente, sans nouvel échec" do
        assert_equal :none, decide(50, nil)
        assert_equal :none, decide(50, :gap, :remediation)
        assert_equal :none, decide(74, :gap, "standard")
      end

      test "au seuil de remédiation (75 %) : résout la lacune en attente selon le type de session" do
        assert_equal 75, Grading::REMEDIATION_THRESHOLD
        assert_equal :remediated, decide(75, :gap, :remediation)
        assert_equal :self_corrected, decide(100, :gap, "standard")
      end
    end
  end
end
