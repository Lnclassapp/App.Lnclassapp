require "test_helper"

module Entities
  module Assessment
    module QuestionKinds
      # CA-8, ADR-0091 §4.2–4.3 : juste seulement si chaque élément de gauche est relié au sien ; trois à cinq paires,
      # côtés droits présents et distincts.
      class MatchingTest < ActiveSupport::TestCase
        def question(*pairs)
          pairs = [ %w[a 1], %w[b 2], %w[c 3] ] if pairs.empty?
          answers = pairs.each_with_index.map do |(left, right), index|
            Answer.new(id: 50 - index, position: index + 1, content: left, correct: true, match_content: right)
          end
          Question.new(id: 1, position: 1, content: "Relie.", explanation: nil, question_type: "matching", answers:)
        end

        test "juste quand chaque gauche, dans l'ordre des positions, choisit sa propre ligne ; une paire fausse, faux" do
          assert question.correct?([ 50, 49, 48 ])
          assert_not question.correct?([ 49, 50, 48 ])
        end

        test "bien formée : chaque droite une fois" do
          assert question.well_formed?([ 48, 50, 49 ])
          assert_not question.well_formed?([ 50, 50, 49 ])
          assert_not question.well_formed?([ 50, 49 ])
          assert_equal [ :display_order, { display_order: [ :incomplete_pairs ] } ], [ Matching::INPUT, Matching::INVALID ]
        end

        test "structure : trois à cinq paires, chaque côté droit présent et unique" do
          assert_empty question.structure_errors
          assert_equal [ :pairs_count ], question(%w[a 1], %w[b 2]).structure_errors
          assert_equal [ :pairs_count ], question(*(1..6).map { [ "g#{it}", "d#{it}" ] }).structure_errors
          assert_equal [ :missing_match ], question(%w[a 1], [ "b", " " ], %w[c 3]).structure_errors
          assert_equal [ :duplicate_match ], question(%w[a Été], %w[b ete], %w[c 3]).structure_errors
        end
      end
    end
  end
end
