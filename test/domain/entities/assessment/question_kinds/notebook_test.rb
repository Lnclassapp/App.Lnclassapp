require "test_helper"

module Entities
  module Assessment
    module QuestionKinds
      # ADR-0115 §4 : travail sur le cahier, aucune réponse, jamais noté, un corrigé type en texte.
      class NotebookTest < ActiveSupport::TestCase
        def question(explanation: "Construction attendue.", answers: [], **fields)
          Question.new(id: 9, position: 1, content: "Sur ton cahier, trace la construction.", explanation:, question_type: "notebook",
                       answers:, **fields)
        end

        test "aucune réponse, jamais corrigé automatiquement, jamais juste" do
          assert_not Notebook::AUTO_GRADED
          assert_equal :none, Notebook::INPUT
          assert_empty Notebook::INVALID
          assert_equal Notebook, Question.kind_for("notebook")
          assert_equal "notebook", Question.kind_name_for("notebook")
          assert_not question.auto_graded?
          assert question.well_formed?(nil)
          assert_not question.correct?(nil)
        end

        test "structure : un corrigé type est obligatoire, aucune proposition" do
          assert_empty question.structure_errors
          assert_equal [ :explanation_required ], question(explanation: nil).structure_errors
          assert_equal [ :answers_not_allowed ], question(answers: [ Answer.new(id: 1, position: 1, content: "a", correct: true) ]).structure_errors
        end

        test "ni début de phrase ni grille sur le cahier" do
          assert_equal [ :starter_not_allowed ], question(starter: "Non, car…").structure_errors
          assert_equal [ :criteria_not_allowed ], question(criteria: [ "Critère" ]).structure_errors
        end
      end
    end
  end
end
