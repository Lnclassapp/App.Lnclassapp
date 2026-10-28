require "test_helper"

module Entities
  module Assessment
    # ADR-0115, PRD §3 : l'appréciation se lit sur la note sur 20 affichée ; « à revoir » nomme les questions corrigées
    # automatiquement et fausses ou sans réponse, la notion pour un exercice de notion, la leçon sinon.
    class AppreciationTest < ActiveSupport::TestCase
      def appreciation(score, outcomes: [], essential_name: nil)
        Appreciation.for(score_percent: score, outcomes:, essential_name:)
      end

      # CA-08 : 20, 16, 15, 12, 11, 10, 9 et 0 sur 20.
      test "les seuils sont lus sur la note affichée sur 20" do
        { 100 => [ 20, :very_good ], 80 => [ 16, :very_good ], 75 => [ 15, :good ], 60 => [ 12, :good ], 55 => [ 11, :fair ],
          50 => [ 10, :fair ], 45 => [ 9, :needs_work ], 0 => [ 0, :needs_work ] }.each do |score, (grade, level)|
          result = appreciation(score)

          assert_equal [ grade, level ], [ result.grade, result.level ], "score #{score}"
        end
      end

      test "79 % s'affiche 16/20 : « Très bien »" do
        result = appreciation(79)

        assert_equal [ 16, :very_good ], [ result.grade, result.level ]
      end

      test "juste avant chaque seuil, le niveau du dessous" do
        { 77 => :good, 57 => :fair, 47 => :needs_work }.each { |score, level| assert_equal level, appreciation(score).level, score.to_s }
        assert_equal :very_good, appreciation(78).level
        assert_equal :good, appreciation(58).level
        assert_equal :fair, appreciation(48).level
      end

      # CA-09 : exercice de la notion « Calculer une longueur », fausse aux questions 2 et 4.
      test "exercice de notion : la notion et les questions en cause" do
        result = appreciation(50, outcomes: [ [ 1, true, true ], [ 2, true, false ], [ 3, true, true ], [ 4, true, false ] ],
                                  essential_name: "Calculer une longueur")

        assert_equal [ :essential, "Calculer une longueur", [ 2, 4 ] ], [ result.scope, result.essential_name, result.weak_numbers ]
        assert_predicate result, :review?
      end

      # CA-10 : exercice de toute la leçon, jamais une notion.
      test "exercice de toute la leçon : les questions en cause, aucune notion" do
        result = appreciation(66, outcomes: [ [ 1, true, true ], [ 2, true, true ], [ 3, true, false ] ])

        assert_equal [ :lesson, nil, [ 3 ] ], [ result.scope, result.essential_name, result.weak_numbers ]
        assert_predicate result, :review?
      end

      test "une réponse rédigée ou un travail sur le cahier n'est jamais en cause" do
        result = appreciation(100, outcomes: [ [ 1, true, true ], [ 2, false, false ], [ 3, false, false ] ])

        assert_empty result.weak_numbers
        assert_not_predicate result, :review?
      end

      # CA-11 : copie sans faute, rien à revoir.
      test "sans faute : rien à revoir" do
        result = appreciation(100, outcomes: [ [ 1, true, true ], [ 2, true, true ] ], essential_name: "Calculer une longueur")

        assert_equal [ :very_good, [], false ], [ result.level, result.weak_numbers, result.review? ]
      end

      test "une question sans réponse (fausse) est en cause, dans l'ordre des numéros" do
        result = appreciation(0, outcomes: [ [ 3, true, false ], [ 1, true, false ], [ 2, true, false ] ])

        assert_equal [ 1, 2, 3 ], result.weak_numbers
      end
    end
  end
end
