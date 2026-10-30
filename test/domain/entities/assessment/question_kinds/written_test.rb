require "test_helper"

module Entities
  module Assessment
    module QuestionKinds
      # ADR-0115 §4 et menace.md (W1 à W5, I3 à I6) : réponse rédigée, 2 000 caractères, jamais notée, corrigé type obligatoire.
      class WrittenTest < ActiveSupport::TestCase
        def question(explanation: "Corrigé type.", answers: [], **fields)
          Question.new(id: 9, position: 1, content: "Justifie.", explanation:, question_type: "written", answers:, **fields)
        end

        test "jamais corrigée automatiquement, jamais juste" do
          assert_not Written::AUTO_GRADED
          assert_equal :response_text, Written::INPUT
          assert_equal({ response_text: [ :invalid ] }, Written::INVALID)
          assert_equal Written, Question.kind_for("written")
          assert_equal "written", Question.kind_name_for("written")
          assert_not question.auto_graded?
          assert_not question.correct?("Non, car AM/AB")
          assert_not question.correct?("")
        end

        # CA-22 et W2 : 2 000 caractères au plus ; vide admis.
        test "bien formée jusqu'à 2 000 caractères, texte vide admis" do
          assert question.well_formed?("")
          assert question.well_formed?("é" * 2_000)
          assert_not question.well_formed?("é" * 2_001)
        end

        test "un octet nul est refusé (PostgreSQL le refuserait) et un texte mal encodé aussi" do
          assert_not question.well_formed?("Non\0 car")
          assert_not question.well_formed?("Non\xFF car".dup.force_encoding(Encoding::UTF_8))
          assert_not question.well_formed?("Non car".b)
          assert_not question.well_formed?(nil)
          assert_not question.well_formed?([ 1 ])
        end

        # W1 : le domaine ne transforme jamais le texte, c'est la vue qui l'échappe.
        test "le texte est gardé tel quel : du HTML reste du texte" do
          text = "Non, car <b>AM/AB</b> <script>alert(1)</script>"

          assert question.well_formed?(text)
          assert_equal "Non, car <b>AM/AB</b> <script>alert(1)</script>", text
        end

        test "structure : un corrigé type est obligatoire et aucune proposition n'est permise" do
          assert_empty question.structure_errors
          assert_equal [ :explanation_required ], question(explanation: nil).structure_errors
          assert_equal [ :explanation_required ], question(explanation: "  ").structure_errors
          assert_equal [ :answers_not_allowed ], question(answers: [ Answer.new(id: 1, position: 1, content: "a", correct: true) ]).structure_errors
        end

        test "structure : début de phrase de 150 caractères au plus" do
          assert_empty question(starter: "Non, car…").structure_errors
          assert_empty question(starter: "a" * 150).structure_errors
          assert_equal [ :starter_too_long ], question(starter: "a" * 151).structure_errors
          assert_empty question(starter: "  ").structure_errors
        end

        test "structure : grille de 8 critères de 150 caractères au plus, sans critère vide" do
          assert_empty question(criteria: Array.new(8) { "Je cite la propriété" }).structure_errors
          assert_empty question(criteria: [ "a" * 150 ]).structure_errors
          assert_equal [ :criteria_too_many ], question(criteria: Array.new(9) { "Critère" }).structure_errors
          assert_equal [ :criteria_too_long ], question(criteria: [ "a" * 151 ]).structure_errors
          assert_equal [ :criteria_blank ], question(criteria: [ "Critère", " " ]).structure_errors
        end
      end
    end
  end
end
