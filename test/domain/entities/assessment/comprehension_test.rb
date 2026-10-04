require "test_helper"

# ADR-0079 §4.2 à §4.7, PRD §4 « Règles de domaine » : la compréhension d'un exercice assigné, aux bornes.
module Entities
  module Assessment
    class ComprehensionTest < ActiveSupport::TestCase
      test "the category of a student is the mastery of his best score, at 49, 50, 69 and 70" do
        assert_equal %i[struggling fragile fragile acquired], [ 49, 50, 69, 70 ].map { Comprehension.category_for(it) }
      end

      test "the sign of progress follows first, best and last, with a margin of 10 points" do
        {
          [ 30, 60, 90 ] => :progress, [ 60, 60, 60 ] => :stagnant, [ 30, 90, 40 ] => :decline, [ 90, 40 ] => :decline,
          [ 100, 100 ] => :stable, [ 50, 59 ] => :stagnant, [ 50, 60 ] => :progress, [ 80, 90, 81 ] => :progress,
          [ 80, 90, 80 ] => :decline
        }.each { |scores, trend| assert_equal trend, Comprehension.trend_for(scores), scores.join("-") }
      end

      test "without any move, the sign is stable from the mastery threshold, stagnant just under it: 70-70 and 69-69" do
        assert_equal :stable, Comprehension.trend_for([ 70, 70 ])
        assert_equal :stagnant, Comprehension.trend_for([ 69, 69 ])
      end

      test "a single attempt has no sign" do
        assert_nil Comprehension.trend_for([ 70 ])
        assert_nil Comprehension.trend_for([])
      end

      test "the dominant category is the most numerous, the most fragile one on a tie, none without students" do
        assert_equal :fragile, Comprehension.dominant({ acquired: 3, fragile: 3, struggling: 1 })
        assert_equal :struggling, Comprehension.dominant({ struggling: 2, fragile: 1, acquired: 2 })
        assert_equal :acquired, Comprehension.dominant({ acquired: 1 })
        assert_nil Comprehension.dominant({ struggling: 0, fragile: 0, acquired: 0 })
      end

      test "the reading of a class is reliable from 5 students who did the exercise" do
        assert_not Comprehension.readable?(4)
        assert Comprehension.readable?(5)
      end

      test "a question is to revisit under the pass threshold, never without attempts" do
        assert Comprehension.to_revisit?(49)
        assert_not Comprehension.to_revisit?(50)
        assert_not Comprehension.to_revisit?(nil)
      end

      test "the named values, and the order of the students: who needs the teacher first" do
        assert_equal 10, Comprehension::PROGRESS_MARGIN
        assert_equal 5, Comprehension::MIN_DONE_FOR_READING
        assert_equal %i[struggling fragile acquired], Comprehension::CATEGORIES
        assert_equal [ :decline, :stagnant, nil, :stable, :progress ], Comprehension::TREND_ORDER
        assert Comprehension::TREND_ORDER.frozen?
      end
    end
  end
end
