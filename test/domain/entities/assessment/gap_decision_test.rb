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

      test "la note affichée décide : 78 % s'affiche 16/20 et lève, 77 % s'affiche 15/20 et ne lève pas" do
        assert_equal [ 16, 15 ], [ 78, 77 ].map { Grading.grade_on_20(it) }
        assert_equal :remediated, decide(78, :gap, :remediation)
        assert_equal :self_corrected, decide(78, :gap, "standard")
        assert_equal :none, decide(77, :gap, :remediation)
      end

      test "Bronze et Argent restent en remédiation : la lacune en attente n'est pas levée, sans nouvel échec" do
        [ 48, 50, 67, 68, 74, 75, 77 ].each do |score|
          assert_includes %i[bronze silver], Grading.badge_for(score)
          assert_equal :none, decide(score, :gap, :remediation), score.to_s
          assert_equal :none, decide(score, :gap, "standard"), score.to_s
          assert_equal :none, decide(score, nil, :remediation), score.to_s
        end
      end

      test "à l'Or et au Diamant : résout la lacune en attente selon le type de session" do
        assert_equal :gold, Grading.badge_for(78)
        assert_equal :remediated, decide(78, :gap, :remediation)
        assert_equal :remediated, decide(100, :gap, :remediation)
        assert_equal :none, decide(80, nil, :remediation)
        assert_equal :self_corrected, decide(100, :gap, "standard")
      end

      test "une lacune ne dépend que de la médaille : elle se lève exactement quand la médaille est Or ou Diamant" do
        (0..100).each do |score|
          lifts = %i[gold diamond].include?(Grading.badge_for(score)) && score >= 50
          assert_equal lifts, %i[remediated self_corrected].include?(decide(score, :gap, :remediation)), score.to_s
        end
      end
    end
  end
end
