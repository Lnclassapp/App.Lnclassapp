require "test_helper"

# rapports-de-classe, Lot C (AS-23 ; ADR-0097 §4.6, UDR-0109) : la phrase « prochain geste » de la section « Compréhension »,
# choisie par une règle à six cas ; le premier cas vrai l'emporte ; même lecture, même phrase.
module Entities
  module Assessment
    class NextStepTest < ActiveSupport::TestCase
      def step(done:, pending: 0, dominant: :acquired, decline: 0)
        NextStep.for(done:, pending:, readable: Comprehension.readable?(done), dominant:, decline:)
      end

      test "1. nobody did it: no next step, the empty state says it" do
        assert_nil step(done: 0, pending: 25)
      end

      test "2. not readable yet with students still to do it: remind them" do
        assert_equal :remind, step(done: 3, pending: 22)
        assert_equal :remind, step(done: 4, pending: 1)
      end

      test "3. not readable, everybody did it: too small a classroom, look at each student" do
        assert_equal :look_at_each, step(done: 4, pending: 0)
      end

      test "4. readable, mostly struggling: revisit the notion, whatever the declines" do
        assert_equal :revisit_notion, step(done: 5, dominant: :struggling, decline: 3)
      end

      test "5. readable, mostly fragile: revisit the marked questions" do
        assert_equal :revisit_questions, step(done: 12, pending: 3, dominant: :fragile)
      end

      test "6. readable, acquired with declining students: watch them" do
        assert_equal :watch_decline, step(done: 20, dominant: :acquired, decline: 2)
      end

      test "7. readable, acquired, nobody declining: move on" do
        assert_equal :move_on, step(done: 5, pending: 1, dominant: :acquired)
      end

      test "the bound of the reading is MIN_DONE_FOR_READING: 4 done is not readable, 5 is" do
        assert_equal :remind, step(done: Comprehension::MIN_DONE_FOR_READING - 1, pending: 1, dominant: :struggling)
        assert_equal :revisit_notion, step(done: Comprehension::MIN_DONE_FOR_READING, pending: 1, dominant: :struggling)
      end

      # Décision du porteur (2026-10-26, maquette) : « Reprenez la question 3 en classe » nomme la moins réussie de la classe.
      test "the question to name is the least successful one, the first on a tie, numbered from 1" do
        assert_equal 3, NextStep.weakest_question([ 90, 65, 30 ])
        assert_equal 2, NextStep.weakest_question([ 90, 30, 30 ])
        assert_equal 1, NextStep.weakest_question([ 0, 50, 0 ])
      end

      test "a question nobody answered is not the least successful; without any attempt there is none to name" do
        assert_equal 2, NextStep.weakest_question([ nil, 40, 80 ])
        assert_nil NextStep.weakest_question([ nil, nil ])
        assert_nil NextStep.weakest_question([])
      end

      test "the same reading gives the same step" do
        assert_equal Array.new(3) { step(done: 8, dominant: :fragile) }.uniq, [ :revisit_questions ]
      end
    end
  end
end
