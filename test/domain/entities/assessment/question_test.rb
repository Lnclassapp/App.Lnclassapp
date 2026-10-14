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
        assert_equal %w[true_false single_choice multiple_correct_2 multiple_correct_3], Question::TYPES
      end

      # ADR-0089 §4.4 : ce qui manque pour publier, sans gêner l'enregistrement d'un brouillon.
      test "image_errors : description sans image, image sans texte de remplacement, ou rien" do
        base = question("true_false", true, false)
        image = ->(alt) { Entities::Shared::ContentImage.new(public_id: "p", alt:) }

        assert_empty base.image_errors
        assert_equal [ :image_missing ], base.with(image_description: "Une pile").image_errors
        assert_empty base.with(image_description: "  ").image_errors
        assert_equal [ :image_alt_blank ], base.with(image: image.(" ")).image_errors
        assert_empty base.with(image_description: "Une pile", image: image.("Une pile")).image_errors
        assert_empty base.with(image_description: "Une pile").structure_errors
      end
    end
  end
end
