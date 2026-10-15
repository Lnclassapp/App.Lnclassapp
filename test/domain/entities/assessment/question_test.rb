require "test_helper"

module Entities
  module Assessment
    class QuestionTest < ActiveSupport::TestCase
      def question(type, *correct_flags)
        answers = correct_flags.each_with_index.map { |correct, index| Answer.new(id: index + 1, position: index, content: "p#{index}", correct:) }
        Question.new(id: 9, position: 0, content: "?", explanation: nil, question_type: type, answers:)
      end

      test "une réponse bien formée a le bon nombre de propositions distinctes de la question" do
        multiple = question("multiple_correct_2", true, true, false)

        assert multiple.well_formed?([ 1, 3 ])
        assert_not multiple.well_formed?([ 1 ])
        assert_not multiple.well_formed?([ 1, 1 ])
        assert_not multiple.well_formed?([ 1, 4 ])
        assert question(:single_choice, false, true).well_formed?([ 2 ])
      end

      test "correcte si l'ensemble choisi est exactement l'ensemble correct" do
        multiple = question("multiple_correct_3", true, false, true, true)

        assert multiple.correct?([ 4, 1, 3 ])
        assert_not multiple.correct?([ 1, 2, 3 ])
      end

      test "structure selon l'ADR-0039 et le PRD (AS-03)" do
        assert_empty question("true_false", true, false).structure_errors
        assert_empty question("single_choice", true, false).structure_errors
        assert_empty question("multiple_correct_2", true, false, true).structure_errors
        assert_empty question("multiple_correct_3", true, true, false, true).structure_errors
        assert_equal [ :true_false_needs_two_answers ], question("true_false", true, false, false).structure_errors
        assert_equal [ :true_false_needs_two_answers ], question("true_false", true).structure_errors
        assert_equal [ :too_few_answers ], question("single_choice", true).structure_errors
        assert_equal [ :too_few_answers ], question("multiple_correct_2", true, true).structure_errors
        assert_equal [ :too_few_answers ], question("multiple_correct_3", true, true, true).structure_errors
        assert_equal [ :wrong_correct_count ], question("single_choice", true, true, false).structure_errors
        assert_equal %i[too_few_answers wrong_correct_count], question("multiple_correct_2", true).structure_errors
        assert_equal [ :unknown_question_type ], Question.structure_errors_for(question_type: "open", answers: [])
        assert_equal [ :unknown_question_type ], Question.structure_errors_for(question_type: nil, answers: [])
      end

      test "une copie sans correction ne dit rien des propositions correctes" do
        copy = question("single_choice", true, false).without_correction

        assert copy.answers.all? { it.correct.nil? }
        assert_equal [ 1, 2 ], copy.answer_ids
      end

      # ADR-0091 §4.3 : huit types ; les quatre de toujours passent par Choice sans changer de comportement.
      test "huit types, chacun délégué à sa classe de règles" do
        assert_equal %w[true_false single_choice multiple_correct_2 multiple_correct_3 fill_blank numeric ordering matching],
                     Question::TYPES
        assert_equal [ QuestionKinds::Choice ], Question::TYPES.first(4).map { Question.kind_for(it) }.uniq
        assert_equal [ QuestionKinds::FillBlank, QuestionKinds::Numeric, QuestionKinds::Ordering, QuestionKinds::Matching ],
                     Question::TYPES.last(4).map { Question.kind_for(it) }
        assert_equal %w[choice fill_blank numeric ordering matching], Question::TYPES.map { Question.kind_name_for(it) }.uniq
        assert_nil Question.kind_for("open")
        assert_nil Question.kind_name_for(nil)
        assert_equal "choice", question(:true_false, true, false).kind_name
        assert_equal Question::EXPECTED, QuestionKinds::Choice::EXPECTED
      end

      test "la marge et le côté droit d'une paire sont facultatifs" do
        assert_nil question("single_choice", true, false).numeric_tolerance
        assert_nil Answer.new(id: 1, position: 1, content: "a", correct: true).match_content
        assert_equal [ 3, 1, 2 ], Question.new(id: 1, position: 1, content: "?", explanation: nil, question_type: "ordering",
                                               answers: [ Answer.new(id: 2, position: 3, content: "c", correct: true),
                                                          Answer.new(id: 3, position: 1, content: "a", correct: true),
                                                          Answer.new(id: 1, position: 2, content: "b", correct: true) ]).ids_by_position
      end
    end
  end
end
