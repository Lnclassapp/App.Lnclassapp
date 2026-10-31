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
          assert question("Cœur").correct?("coeur")
          assert question("Ex æquo").correct?("ex aequo")
          assert question("Saint\u2011Louis").correct?("saint-louis")
          assert question("x \u2212 1").correct?("x - 1")
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
          assert_equal [ :duplicate_accepted ], question("Abidjan", " ABIDJAN ").structure_errors
        end

        # ADR cases §4 : 1 à 5 réponses acceptées par case, autant de `___` que de cases, au plus 6 cases.
        def multi(*cases, content: nil)
          id = 0
          answers = cases.each_with_index.flat_map do |accepted, blank|
            accepted.map { |text| Answer.new(id: id += 1, position: id, content: text, correct: true, blank:) }
          end
          Question.new(id: 1, position: 1, content: content || (%w[___] * cases.size).join(" et "), explanation: nil, question_type: "fill_blank", answers:)
        end

        test "plusieurs cases : chaque case a ses réponses acceptées" do
          two = multi(%w[Abidjan Yamoussoukro], [ "Côte d'Ivoire" ])

          assert_equal 2, two.blanks
          assert_equal [ true, true ], two.blank_results([ "abidjan", "cote d’ivoire" ])
          assert_equal [ false, true ], two.blank_results([ "Côte d'Ivoire", "COTE D'IVOIRE" ])
          assert_equal [ false, false ], two.blank_results([ "", "  " ])
          assert two.correct?([ "Yamoussoukro", "côte d'ivoire" ])
          assert_not two.correct?([ "Abidjan", "Abidjan" ])
        end

        test "une question à une case a un seul verdict" do
          assert_equal [ true ], question("Abidjan").blank_results("abidjan")
          assert_equal [ false ], question("Abidjan").blank_results("Abidjn")
        end

        test "plusieurs cases : une réponse par case, une case vide est fausse sans refuser la copie" do
          two = multi(%w[a], %w[b])

          assert two.well_formed?([ "a", "" ])
          assert_not two.well_formed?([ "a" ])
          assert_not two.well_formed?([ "a", "b", "c" ])
          assert_not two.well_formed?("a")
        end

        # CA-13 : une case sans réponse acceptée est refusée.
        test "structure : autant de ___ que de cases, de une à cinq réponses acceptées par case" do
          assert_empty multi(%w[a], %w[b], %w[c]).structure_errors
          assert_empty multi(%w[a b c d e], %w[f]).structure_errors
          assert_equal [ :blank_markers_mismatch ], multi(%w[a], %w[b], content: "Un ___ seul").structure_errors
          assert_equal [ :blank_markers_mismatch ], multi(%w[a], %w[b], content: "___ ___ ___").structure_errors
          assert_equal [ :accepted_answers_count ], multi(%w[a], %w[a b c d e f]).structure_errors
          assert_equal [ :duplicate_accepted ], multi(%w[a], [ "b", " B " ]).structure_errors
          assert_empty multi(%w[a], %w[a]).structure_errors
        end

        test "structure : une case sans réponse acceptée est refusée" do
          gap = multi(%w[a], %w[b], %w[c]).then { it.with(answers: it.answers.reject { |a| a.blank == 1 }) }

          assert_equal [ :blank_without_answer ], gap.structure_errors
        end

        test "structure : au plus six cases" do
          seven = multi(*(%w[a] * 7).map { [ it ] })

          assert_equal [ :too_many_blanks ], seven.structure_errors
        end
      end
    end
  end
end
