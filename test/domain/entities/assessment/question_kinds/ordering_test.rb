require "test_helper"

module Entities
  module Assessment
    module QuestionKinds
      # CA-7, ADR-0091 §4.2–4.3 : juste seulement si toutes les étapes sont à leur place ; trois à six étapes.
      class OrderingTest < ActiveSupport::TestCase
        # Les ids ne suivent pas les positions : la bonne réponse est l'ordre des positions, pas celui des ids.
        def question(count = 4)
          answers = (1..count).map { |position| Answer.new(id: 100 - position, position:, content: "Étape #{position}", correct: true) }
          Question.new(id: 1, position: 1, content: "Range.", explanation: nil, question_type: "ordering", answers:)
        end

        test "juste dans l'ordre des positions ; une seule étape mal placée, faux" do
          assert question.correct?([ 99, 98, 97, 96 ])
          assert_not question.correct?([ 98, 99, 97, 96 ])
          assert_not question.correct?([ 96, 97, 98, 99 ])
        end

        test "bien formée : chaque étape une fois, aucune d'ailleurs" do
          assert question.well_formed?([ 96, 98, 97, 99 ])
          assert_not question.well_formed?([ 99, 98, 97 ])
          assert_not question.well_formed?([ 99, 99, 97, 96 ])
          assert_not question.well_formed?([])
          assert_equal [ :display_order, { display_order: [ :wrong_order ] } ], [ Ordering::INPUT, Ordering::INVALID ]
        end

        test "structure : de trois à six étapes" do
          assert_empty question(3).structure_errors
          assert_empty question(6).structure_errors
          assert_equal [ :steps_count ], question(2).structure_errors
          assert_equal [ :steps_count ], question(7).structure_errors
        end
      end
    end
  end
end
