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
          assert_equal BigDecimal("3.5"), Numeric.parse("\u00A03,5\u202F\n")
          # ADR-0091 §4.3 : le point est toujours décimal, jamais le séparateur des milliers.
          assert_equal 1, Numeric.parse("1.000")
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
          assert question("3,5", tolerance: BigDecimal("0.1")).correct?("3.4")
          assert_not question("3,5", tolerance: BigDecimal("0.1")).correct?("3.39")
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
          assert_empty question("3", tolerance: BigDecimal("99999999.9999")).structure_errors
          [ BigDecimal("1e30"), BigDecimal("100000000"), BigDecimal("0.00001"), BigDecimal("Infinity") ].each do |tolerance|
            assert_equal [ :tolerance_out_of_range ], question("3", tolerance:).structure_errors, tolerance.to_s
          end
        end

        # ADR-0115 §4, CA-20 : une réponse qui finit par l'unité, espaces compris, est lue sans elle.
        test "l'unité est retirée de la fin de la réponse : 4,8, 4.8 et 4,8 cm sont justes" do
          cm = question("4,8").with(unit: "cm")

          [ "4,8", "4.8", "4,8 cm", "4,8cm", " 4,8 cm ", "4.8   cm" ].each do |text|
            assert cm.well_formed?(text), text.inspect
            assert cm.correct?(text), text.inspect
          end
          assert_not cm.correct?("4,9 cm")
        end

        test "une autre unité, ou l'unité ailleurs qu'à la fin, est une saisie mal formée" do
          cm = question("4,8").with(unit: "cm")

          [ "48 mm", "4,8 m", "cm 4,8", "4 cm 8", "cm", "4,8 cm cm", "4,8 CM" ].each do |text|
            assert_not cm.well_formed?(text), text.inspect
          end
          assert_not question("4,8").well_formed?("4,8 cm")
        end

        # Menace I2 : l'unité est un texte, jamais un motif ; et elle ne peut pas manger un chiffre de la réponse.
        test "une unité à métacaractères ne casse rien, une unité chiffrée est refusée à la structure" do
          odd = question("4,8").with(unit: "^$|(")

          assert odd.well_formed?("4,8 ^$|(")
          assert_not odd.well_formed?("4,8 cm")
          assert_equal [ :unit_invalid ], question("4,8").with(unit: "0").structure_errors
          assert_not question("4").with(unit: "0").correct?("40")
          assert question("40").with(unit: "0").correct?("40")
        end

        test "structure : 10 caractères au plus, sans chiffre, signe ni séparateur décimal" do
          assert_empty question("4,8").with(unit: "km/h").structure_errors
          assert_empty question("4,8").with(unit: "m²").structure_errors
          assert_empty question("4,8").with(unit: "a" * 10).structure_errors
          assert_empty question("4,8").with(unit: "  ").structure_errors
          assert_equal [ :unit_too_long ], question("4,8").with(unit: "a" * 11).structure_errors
          %w[0 m3 - + , . −].each { assert_equal [ :unit_invalid ], question("4,8").with(unit: it).structure_errors, it }
        end
      end
    end
  end
end
