require "test_helper"

module Entities
  module Assessment
    module QuestionKinds
      # CA-4, ADR-0091 §4.2–4.3 : juste sans casse, accents, apostrophe typographique ni espaces en trop ; une faute de frappe
      # est fausse ; `___` une seule fois dans l'énoncé, une à cinq réponses acceptées.
      class FillBlankTest < ActiveSupport::TestCase
        def question(*accepted, content: "La capitale économique de la Côte d'Ivoire est ___ .")
          Question.new(id: 1, position: 1, content:, explanation: nil, question_type: "fill_blank",
                       answers: accepted.each_with_index.map { |text, index| Answer.new(id: index + 1, position: index + 1, content: text, correct: true) })
        end

        test "juste sans tenir compte des majuscules, des accents, des apostrophes ni des espaces en trop" do
          assert question("Abidjan").correct?("ABIDJAN  ")
          assert question("Côte d'Ivoire").correct?("  cote   d’ivoire")
          assert question("Yamoussoukro", "Abidjan").correct?("abidjan")
        end

        test "une faute de frappe est fausse" do
          assert_not question("Abidjan").correct?("Abidjn")
          assert_not question("Abidjan").correct?("Abidjan-Plateau")
        end

        test "un texte vide n'est pas une réponse ; son erreur est celle du blanc" do
          assert question("Abidjan").well_formed?("x")
          assert_not question("Abidjan").well_formed?("   ")
          assert_equal({ response_text: [ :blank_text ] }, FillBlank::INVALID)
          assert_equal :response_text, FillBlank::INPUT
        end

        test "structure : `___` une seule fois, de une à cinq réponses acceptées" do
          assert_empty question("Abidjan").structure_errors
          assert_empty question(*%w[a b c d e]).structure_errors
          assert_equal [ :blank_marker ], question("Abidjan", content: "Sans blanc.").structure_errors
          assert_equal [ :blank_marker ], question("Abidjan", content: "___ et ___").structure_errors
          assert_equal [ :accepted_answers_count ], question.structure_errors
          assert_equal [ :accepted_answers_count ], question(*%w[a b c d e f]).structure_errors
        end
      end
    end
  end
end
