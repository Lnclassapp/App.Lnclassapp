require "test_helper"

module Entities
  module Assessment
    module QuestionKinds
      # ADR-0115 §4 : choix dans une liste, 2 à 10 propositions dont une seule correcte, `___` au plus une fois.
      class SelectTest < ActiveSupport::TestCase
        def answers(*flags)
          flags.each_with_index.map { |correct, index| Answer.new(id: index + 1, position: index + 1, content: "Choix #{index}", correct:) }
        end

        def question(*flags, content: "Les points sont ___.")
          Question.new(id: 9, position: 1, content:, explanation: nil, question_type: "select", answers: answers(*flags))
        end

        test "corrigé automatiquement, la réponse est l'identifiant de la proposition choisie" do
          assert Select::AUTO_GRADED
          assert_equal :answer_ids, Select::INPUT
          assert_equal({ answer_ids: [ :wrong_selection ] }, Select::INVALID)
          assert_equal Select, Question.kind_for("select")
          assert_equal "select", Question.kind_name_for("select")
        end

        # CA-18 : choisir la bonne proposition est juste, une autre est fausse.
        test "juste si la proposition choisie est la correcte" do
          list = question(false, true, false)

          assert list.correct?([ 2 ])
          assert_not list.correct?([ 1 ])
          assert_not list.correct?([ 3 ])
        end

        test "bien formée : une seule proposition, de la question" do
          list = question(false, true)

          assert list.well_formed?([ 1 ])
          assert_not list.well_formed?([])
          assert_not list.well_formed?([ 1, 2 ])
          assert_not list.well_formed?([ 99 ])
        end

        test "structure : de 2 à 10 propositions, une seule correcte" do
          assert_empty question(true, false).structure_errors
          assert_empty question(*([ true ] + [ false ] * 9)).structure_errors
          assert_equal [ :options_count ], question(*([ true ] + [ false ] * 10)).structure_errors
          assert_equal [ :options_count ], question(true).structure_errors
          assert_equal [ :wrong_correct_count ], question(false, false).structure_errors
          assert_equal [ :wrong_correct_count ], question(true, true, false).structure_errors
        end

        test "structure : le trou ___ est facultatif, mais une seule fois au plus" do
          assert_empty question(true, false, content: "Sans trou.").structure_errors
          assert_empty question(true, false, content: "Un ___ trou.").structure_errors
          assert_equal [ :blank_marker ], question(true, false, content: "Deux ___ et ___.").structure_errors
        end

        test "structure : propositions distinctes (casse, accents et espaces ignorés) et non vides" do
          twins = Question.new(id: 9, position: 1, content: "?", explanation: nil, question_type: "select",
                               answers: [ Answer.new(id: 1, position: 1, content: "Alignés", correct: true),
                                          Answer.new(id: 2, position: 2, content: " aligNes ", correct: false) ])
          empty = Question.new(id: 9, position: 1, content: "?", explanation: nil, question_type: "select",
                               answers: [ Answer.new(id: 1, position: 1, content: "Alignés", correct: true),
                                          Answer.new(id: 2, position: 2, content: "  ", correct: false) ])

          assert_equal [ :duplicate_options ], twins.structure_errors
          assert_equal [ :blank_option ], empty.structure_errors
        end
      end
    end
  end
end
