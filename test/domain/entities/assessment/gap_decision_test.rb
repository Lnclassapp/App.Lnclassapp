require "test_helper"

module Entities
  module Assessment
    class GapDecisionTest < ActiveSupport::TestCase
      def decide(score, gap, kind = "standard", treated: true) = GapDecision.call(score_percent: score, pending_gap: gap, session_kind: kind, treated:)

      test "sous l'Or : ouvre ou incrémente, du 0 % à l'Argent" do
        assert_equal :open, decide(47, nil)
        assert_equal :increment, decide(0, :gap)
        assert_equal :open, decide(60, nil)
        assert_equal :increment, decide(74, :gap, :remediation)
      end

      # Décision du porteur (2026-11-09) : la note affichée décide ; 77 % s'affiche 15/20 (Argent) et ouvre, 78 % s'affiche 16/20 (Or).
      test "49 % s'affiche 10/20 (Bronze) : ouvre, et compte un échec de plus" do
        assert_equal [ 10, 9 ], [ 49, 47 ].map { Grading.grade_on_20(it) }
        assert_equal :open, decide(49, nil)
        assert_equal :increment, decide(49, :gap)
        assert_equal :increment, decide(48, :gap)
      end

      test "copie vide : aucune médaille, n'ouvre rien et ne compte rien" do
        assert_equal :none, decide(0, nil, treated: false)
        assert_equal :none, decide(0, :gap, :remediation, treated: false)
        assert_equal :none, decide(100, :gap, "standard", treated: false)
      end

      test "la note affichée décide : 78 % s'affiche 16/20 et lève, 77 % s'affiche 15/20 et reste à revoir" do
        assert_equal [ 16, 15 ], [ 78, 77 ].map { Grading.grade_on_20(it) }
        assert_equal :remediated, decide(78, :gap, :remediation)
        assert_equal :self_corrected, decide(78, :gap, "standard")
        assert_equal :increment, decide(77, :gap, :remediation)
      end

      test "Bronze et Argent sont en remédiation : ouvrent, ou comptent un échec de plus, sans jamais lever" do
        [ 48, 50, 67, 68, 74, 75, 77 ].each do |score|
          assert_includes %i[bronze silver], Grading.badge_for(score)
          assert_equal :increment, decide(score, :gap, :remediation), score.to_s
          assert_equal :increment, decide(score, :gap, "standard"), score.to_s
          assert_equal :open, decide(score, nil, :remediation), score.to_s
        end
      end

      test "à l'Or et au Diamant : résout la lacune en attente selon le type de session" do
        assert_equal :gold, Grading.badge_for(78)
        assert_equal :remediated, decide(78, :gap, :remediation)
        assert_equal :remediated, decide(100, :gap, :remediation)
        assert_equal :none, decide(80, nil, :remediation)
        assert_equal :self_corrected, decide(100, :gap, "standard")
      end

      # Toute l'échelle 0 à 100, lue par la médaille : Or et Diamant ne sont pas en remédiation, Bronze et Argent y sont.
      test "une seule échelle : la lacune s'ouvre exactement quand la médaille est Bronze ou Argent, et se lève quand elle est Or ou Diamant" do
        (0..100).each do |score|
          in_remediation = %i[bronze silver].include?(Grading.badge_for(score))
          assert_equal (in_remediation ? :open : :none), decide(score, nil, :remediation), score.to_s
          assert_equal (in_remediation ? :increment : :remediated), decide(score, :gap, :remediation), score.to_s
          assert_equal (in_remediation ? :increment : :self_corrected), decide(score, :gap, "standard"), score.to_s
        end
      end
    end
  end
end
