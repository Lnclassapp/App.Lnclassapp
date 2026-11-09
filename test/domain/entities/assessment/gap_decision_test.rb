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

      test "la note affichée décide : 68 % s'affiche 14/20 et lève, 67 % s'affiche 13/20 et ne lève pas" do
        assert_equal [ 14, 13 ], [ 68, 67 ].map { Grading.grade_on_20(it) }
        assert_equal :remediated, decide(68, :gap, :remediation)
        assert_equal :self_corrected, decide(68, :gap, "standard")
        assert_equal :none, decide(67, :gap, :remediation)
      end

      test "entre la réussite et le seuil de remédiation : la lacune reste en attente, sans nouvel échec" do
        assert_equal :none, decide(50, nil)
        assert_equal :none, decide(50, :gap, :remediation)
        assert_equal :none, decide(60, :gap, "standard")
      end

      test "au seuil de remédiation (l'Argent, 70 %) : résout la lacune en attente selon le type de session" do
        assert_equal 70, Grading::REMEDIATION_THRESHOLD
        assert_equal :remediated, decide(70, :gap, :remediation)
        assert_equal :none, decide(70, nil, :remediation)
        assert_equal :self_corrected, decide(100, :gap, "standard")
      end
    end
  end
end
