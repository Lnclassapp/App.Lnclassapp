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

        # ADR cases §4 : 2 à 10 propositions par case, dont une seule correcte ; au plus 6 cases.
        def multi(*cases, content: nil)
          id = 0
          answers = cases.each_with_index.flat_map do |flags, blank|
            flags.map { |correct| Answer.new(id: id += 1, position: id, content: "Choix #{id}", correct:, blank:) }
          end
          Question.new(id: 9, position: 1, content: content || (%w[___] * cases.size).join(" puis "), explanation: nil, question_type: "select", answers:)
        end

        test "plusieurs cases : le verdict de chaque case, une proposition par case" do
          two = multi([ false, true ], [ true, false, false ])

          assert_equal 2, two.blanks
          assert_equal [ true, true ], two.blank_results([ 2, 3 ])
          assert_equal [ true, false ], two.blank_results([ 2, 4 ])
          assert_equal [ false, false ], two.blank_results([ nil, nil ])
          assert two.correct?([ 2, 3 ])
          assert_not two.correct?([ 2, 4 ])
          assert_not two.correct?([ 1, 3 ])
        end

        test "une question à une case a un seul verdict" do
          assert_equal [ true ], question(false, true).blank_results([ 2 ])
          assert_equal [ false ], question(false, true).blank_results([ 1 ])
        end

        test "plusieurs cases : bien formée si chaque proposition est de sa case, une case laissée vide est fausse" do
          two = multi([ false, true ], [ true, false ])

          assert two.well_formed?([ 2, 3 ])
          assert two.well_formed?([ nil, 3 ])
          assert_not two.well_formed?([ 3, 3 ])
          assert_not two.well_formed?([ 2 ])
          assert_not two.well_formed?([ 2, 3, 3 ])
        end

        test "structure : chaque case a ses propositions, autant de ___ que de cases" do
          assert_empty multi([ true, false ], [ false, true, false ]).structure_errors
          assert_equal [ :blank_markers_mismatch ], multi([ true, false ], [ false, true ], content: "Un ___").structure_errors
          assert_equal [ :options_count ], multi([ true, false ], [ true ]).structure_errors
          assert_equal [ :wrong_correct_count ], multi([ true, false ], [ false, false ]).structure_errors
        end

        test "plusieurs cases : une case sans proposition correcte n'est jamais juste, quoi qu'on y choisisse" do
          gap = multi([ true, false ], [ true, false ], [ true, false ]).then { it.with(answers: it.answers.reject { |a| a.blank == 1 }) }

          assert_equal [ true, false, true ], gap.blank_results([ 1, 3, 5 ])
          assert_not gap.correct?([ 1, 3, 5 ])
        end

        test "structure : une case sans proposition est refusée" do
          gap = multi([ true, false ], [ true, false ], [ true, false ]).then { it.with(answers: it.answers.reject { |a| a.blank == 1 }) }

          assert_equal [ :blank_without_answer ], gap.structure_errors
        end

        test "structure : les propositions d'une case sont distinctes, mais deux cases peuvent répéter la même" do
          same = Question.new(id: 9, position: 1, content: "___ ___", explanation: nil, question_type: "select",
                              answers: [ Answer.new(id: 1, position: 1, content: "Vrai", correct: true, blank: 0), Answer.new(id: 2, position: 2, content: "Faux", correct: false, blank: 0),
                                         Answer.new(id: 3, position: 3, content: "Vrai", correct: true, blank: 1), Answer.new(id: 4, position: 4, content: "Faux", correct: false, blank: 1) ])

          assert_empty same.structure_errors
          assert_equal [ :duplicate_options ], same.with(answers: same.answers.map { it.id == 4 ? it.with(content: "vrai") : it }).structure_errors
        end
      end
    end
  end
end
