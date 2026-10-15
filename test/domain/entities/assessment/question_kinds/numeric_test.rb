require "test_helper"

module Entities
  module Assessment
    module QuestionKinds
      # ADR-0091 §4.3 : un nombre saisi au clavier d'un téléphone, avec la virgule ou le point, le moins ASCII ou Unicode,
      # et les espaces des milliers. Le reste est illisible.
      class NumericTest < ActiveSupport::TestCase
        test "virgule ou point, moins ASCII ou Unicode, espaces des milliers" do
          assert_equal BigDecimal("3.5"), Numeric.parse("3,5")
          assert_equal BigDecimal("3.5"), Numeric.parse(" 3.5 ")
          assert_equal BigDecimal("-2"), Numeric.parse("−2")
          assert_equal BigDecimal("-2"), Numeric.parse("-2")
          assert_equal BigDecimal("1000.25"), Numeric.parse("1 000,25")
          assert_equal BigDecimal("12000"), Numeric.parse("12 000")
        end

        test "une saisie illisible rend nil" do
          [ "3,,5", "", " ", "abc", "3.", ",5", "--2", "2-", "1e3", "3,5,1", nil ].each do |text|
            assert_nil Numeric.parse(text), text.inspect
          end
        end
        def question(value, tolerance: nil, values: [ value ])
          Question.new(id: 1, position: 1, content: "Combien ?", explanation: nil, question_type: "numeric", numeric_tolerance: tolerance,
                       answers: values.each_with_index.map { |text, index| Answer.new(id: index + 1, position: index + 1, content: text, correct: true) })
        end

        # CA-5, CA-6 : la marge s'applique, la virgule vaut le point, le moins Unicode est lu ; sans marge, la valeur exacte.
        test "juste dans la marge, faux au-delà ; sans marge, la valeur exacte seule" do
          assert question("3,5", tolerance: BigDecimal("0.1")).correct?("3.45")
          assert question("3,5", tolerance: BigDecimal("0.1")).correct?("3,6")
          assert_not question("3,5", tolerance: BigDecimal("0.1")).correct?("3.61")
          assert question("-2").correct?("−2")
          assert question("3.5").correct?("3,50")
          assert_not question("3.5").correct?("3.51")
        end

        test "une saisie illisible n'est pas une réponse : erreur de saisie, jamais « Mauvaise réponse »" do
          assert question("3,5").well_formed?("3,5")
          assert_not question("3,5").well_formed?("3,,5")
          assert_equal({ response_text: [ :not_a_number ] }, Numeric::INVALID)
        end

        test "structure : une seule valeur lisible, une marge positive ou nulle" do
          assert_empty question("-3,5", tolerance: BigDecimal("0")).structure_errors
          assert_equal [ :numeric_needs_one_value ], question(nil, values: %w[1 2]).structure_errors
          assert_equal [ :numeric_needs_one_value ], question(nil, values: []).structure_errors
          assert_equal [ :numeric_value_unreadable ], question("trois").structure_errors
          assert_equal [ :negative_tolerance ], question("3", tolerance: BigDecimal("-0.1")).structure_errors
        end
      end
    end
  end
end
