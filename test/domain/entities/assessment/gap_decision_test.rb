require "test_helper"

module Entities
  module Assessment
    class GapDecisionTest < ActiveSupport::TestCase
      def decide(score, gap, kind = "standard") = GapDecision.call(score_percent: score, pending_gap: gap, session_kind: kind)

      test "sous le seuil : ouvre ou incrémente" do
        assert_equal :open, decide(47, nil)
        assert_equal :increment, decide(0, :gap)
      end

      # Décision du porteur (2026-10-19, ADR-0101 §4.5) : la note affichée sur 20 décide, pas le pourcentage brut.
      test "la note affichée décide : 49 % s'affiche 10/20 et n'ouvre pas, 47 % s'affiche 9/20 et ouvre" do
        assert_equal [ 10, 9 ], [ 49, 47 ].map { Grading.grade_on_20(it) }
        assert_equal :none, decide(49, nil)
        assert_equal :none, decide(49, :gap)
        assert_equal :none, decide(48, :gap)
        assert_equal [ true, false ], [ 48, 47 ].map { Grading.reaches?(it, Grading::PASS_THRESHOLD) }
        assert_equal :open, decide(47, nil)
        assert_equal :increment, decide(47, :gap)
      end

      test "la note affichée décide : 74 % s'affiche 15/20 et lève, 72 % s'affiche 14/20 et ne lève pas" do
        assert_equal [ 15, 14 ], [ 74, 72 ].map { Grading.grade_on_20(it) }
        assert_equal :remediated, decide(74, :gap, :remediation)
        assert_equal :self_corrected, decide(74, :gap, "standard")
        assert_equal :none, decide(72, :gap, :remediation)
        assert_equal :remediated, decide(73, :gap, :remediation)
      end

      test "entre la réussite et le seuil de remédiation : la lacune reste en attente, sans nouvel échec" do
        assert_equal :none, decide(50, nil)
        assert_equal :none, decide(50, :gap, :remediation)
        assert_equal :none, decide(72, :gap, "standard")
      end

      test "au seuil de remédiation (75 %) : résout la lacune en attente selon le type de session" do
        assert_equal 75, Grading::REMEDIATION_THRESHOLD
        assert_equal :remediated, decide(75, :gap, :remediation)
        assert_equal :none, decide(75, nil, :remediation)
        assert_equal :self_corrected, decide(100, :gap, "standard")
      end
    end
  end
end
