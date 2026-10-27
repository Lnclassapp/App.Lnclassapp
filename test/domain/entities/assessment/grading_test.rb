require "test_helper"

module Entities
  module Assessment
    class GradingTest < ActiveSupport::TestCase
      # ADR-0106 : la note affichée sur 20 décide. Bronze dès 10/20 (48 %), Argent dès 14/20 (68 %), Or dès 16/20 (78 %).
      test "badge aux bornes des paliers, lus sur la note sur 20" do
        assert_nil Grading.badge_for(47)
        { 48 => :bronze, 67 => :bronze, 68 => :silver, 77 => :silver, 78 => :gold, 97 => :gold, 99 => :gold,
          100 => :diamond }.each { |score, badge| assert_equal badge, Grading.badge_for(score), score.to_s }
      end

      test "reaches? compare les notes sur 20 : chaque seuil est atteint à sa borne, pas un point avant" do
        { Grading::PASS_THRESHOLD => [ 47, 48 ], Grading::MASTERY_THRESHOLD => [ 67, 68 ],
          Grading::REMEDIATION_THRESHOLD => [ 72, 73 ], Grading::GOLD_THRESHOLD => [ 77, 78 ] }.each do |threshold, (below, at)|
          assert_not Grading.reaches?(below, threshold), "#{below} sous #{threshold}"
          assert Grading.reaches?(at, threshold), "#{at} sur #{threshold}"
          assert_equal Grading.grade_on_20(at), Grading.grade_on_20(threshold)
        end
        assert Grading.reaches?(100, Grading::PERFECT_THRESHOLD)
        assert_not Grading.reaches?(0, Grading::PASS_THRESHOLD)
      end

      test "le Diamant est le sans-faute, pas une note : 98 % s'affiche 20/20 sans Diamant" do
        assert_equal [ 20, 20, 20 ], [ 98, 99, 100 ].map { Grading.grade_on_20(it) }
        assert_equal [ false, false, true ], [ 98, 99, 100 ].map { Grading.perfect?(it) }
        assert_equal [ :gold, :gold, :diamond ], [ 98, 99, 100 ].map { Grading.badge_for(it) }
      end

      test "9 bonnes réponses sur 10 donnent 90 et Or, jamais Diamant" do
        score = Grading.score_percent(correct: 9, total: 10)

        assert_equal 90, score
        assert_equal :gold, Grading.badge_for(score)
      end

      # UDR enseignant §3.2 (CA-G3) : le badge d'un élève dans une classe, sur ses exercices faits (notes retenues, sur 100).
      test "class_badge_for: Diamant seulement si au moins un exercice est fait et tous sans faute" do
        assert_equal :diamond, Grading.class_badge_for(scores: [ 100 ], all_perfect: true)
        assert_equal :diamond, Grading.class_badge_for(scores: [ 100, 100, 100 ], all_perfect: true)
        assert_equal :gold, Grading.class_badge_for(scores: [ 100, 98 ], all_perfect: false)
      end

      test "class_badge_for: Or, Argent, Bronze selon la moyenne, lue sur la note sur 20" do
        { [ 78 ] => :gold, [ 90, 70 ] => :gold, [ 77 ] => :silver, [ 68 ] => :silver, [ 67 ] => :bronze, [ 48 ] => :bronze,
          [ 60, 40 ] => :bronze }.each do |scores, badge|
          assert_equal badge, Grading.class_badge_for(scores:, all_perfect: false), scores.inspect
        end
      end

      test "class_badge_for: nil, « Pas encore », sans exercice fait ou sous la moyenne de Bronze" do
        assert_nil Grading.class_badge_for(scores: [], all_perfect: false)
        assert_nil Grading.class_badge_for(scores: [], all_perfect: true)
        assert_nil Grading.class_badge_for(scores: [ 47 ], all_perfect: false)
        assert_nil Grading.class_badge_for(scores: [ 60, 30 ], all_perfect: false)
      end

      test "le score est une division entière, arrondie vers le bas" do
        assert_equal 66, Grading.score_percent(correct: 2, total: 3)
        assert_equal 0, Grading.score_percent(correct: 0, total: 0)
      end

      test "note sur 20 et maîtrise, lues sur la note affichée" do
        assert_equal 14, Grading.grade_on_20(70)
        assert_equal 13, Grading.grade_on_20(66)
        assert_equal 20, Grading.grade_on_20(100)
        { 47 => :struggling, 48 => :fragile, 67 => :fragile, 68 => :acquired, 70 => :acquired }.each do |score, mastery|
          assert_equal mastery, Grading.mastery_for(score), score.to_s
        end
      end

      test "un badge ne monte que vers un palier strictement supérieur" do
        assert Grading.upgrade?(nil, :bronze)
        assert Grading.upgrade?("bronze", :gold)
        assert_not Grading.upgrade?(:gold, :gold)
        assert_not Grading.upgrade?(:gold, :silver)
        assert_not Grading.upgrade?(:gold, nil)
      end
    end
  end
end
