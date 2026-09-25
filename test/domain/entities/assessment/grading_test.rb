require "test_helper"

module Entities
  module Assessment
    class GradingTest < ActiveSupport::TestCase
      test "badge aux bornes des paliers" do
        assert_nil Grading.badge_for(49)
        { 50 => :bronze, 69 => :bronze, 70 => :silver, 79 => :silver, 80 => :gold, 99 => :gold,
          100 => :diamond }.each { |score, badge| assert_equal badge, Grading.badge_for(score), score.to_s }
      end

      test "9 bonnes réponses sur 10 donnent 90 et Or, jamais Diamant" do
        score = Grading.score_percent(correct: 9, total: 10)

        assert_equal 90, score
        assert_equal :gold, Grading.badge_for(score)
      end

      test "le score est une division entière, arrondie vers le bas" do
        assert_equal 66, Grading.score_percent(correct: 2, total: 3)
        assert_equal 0, Grading.score_percent(correct: 0, total: 0)
      end

      test "note sur 20 et maîtrise" do
        assert_equal 14, Grading.grade_on_20(70)
        assert_equal 13, Grading.grade_on_20(66)
        assert_equal 20, Grading.grade_on_20(100)
        { 49 => :struggling, 50 => :fragile, 69 => :fragile, 70 => :acquired }.each do |score, mastery|
          assert_equal mastery, Grading.mastery_for(score)
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
