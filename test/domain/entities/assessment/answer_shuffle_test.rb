require "test_helper"

module Entities
  module Assessment
    # ADR-0091 §4.4 et §5 : le mélange est gelé. Une session ouverte avant le chantier se reprend à l'identique, et les
    # indices d'affichage postés se relisent avec le même mélange. Ces valeurs ne doivent jamais changer.
    class AnswerShuffleTest < ActiveSupport::TestCase
      test "le mélange est figé pour une graine donnée" do
        assert_equal [ 10, 11, 13, 12 ], AnswerShuffle.for(session_id: 7, question_id: 3, ids: [ 13, 10, 12, 11 ])
        assert_equal [ 103, 101, 104, 106, 105, 102 ], AnswerShuffle.for(session_id: 4242, question_id: 977, ids: (101..106).to_a)
      end

      test "même résultat que l'ancien mélange de SessionPlayQuery : [id, contenu] triés par id, graine session ^ question" do
        rows = [ [ 21, "a" ], [ 22, "b" ], [ 23, "c" ], [ 24, "d" ], [ 25, "e" ] ]
        former = rows.shuffle(random: Random.new(31 ^ 8)).map(&:first)

        assert_equal former, AnswerShuffle.for(session_id: 31, question_id: 8, ids: rows.map(&:first).reverse)
      end

      # ADR-0091 §4.4 : l'ordre et relier ne s'affichent jamais déjà résolus ; un cran de rotation suffit.
      test "avec avoid, le mélange ne donne jamais la solution, pour de nombreuses graines ; sans avoid, il ne change pas" do
        ids = [ 11, 12, 13 ]
        (1..2000).each do |seed|
          assert_not_equal ids, AnswerShuffle.for(session_id: seed, question_id: 7, ids:, avoid: ids), "graine #{seed}"
        end
        identity = (1..2000).find { AnswerShuffle.for(session_id: it, question_id: 7, ids:) == ids }
        assert_equal ids.rotate, AnswerShuffle.for(session_id: identity, question_id: 7, ids:, avoid: ids)
        assert_equal [ 42 ], AnswerShuffle.for(session_id: 1, question_id: 7, ids: [ 42 ], avoid: [ 42 ])
      end

      test "les indices d'affichage d'une permutation désignent les identifiants, dans l'ordre de l'élève" do
        assert_equal [ 13, 10, 12, 11 ], AnswerShuffle.pick([ 10, 11, 13, 12 ], [ 2, 0, 3, 1 ])
      end

      test "un indice manquant, en double ou hors bornes rend une réponse vide, donc mal formée" do
        shuffled = [ 10, 11, 13 ]

        assert_equal [], AnswerShuffle.pick(shuffled, [ 0, 1 ])
        assert_equal [], AnswerShuffle.pick(shuffled, [ 0, 0, 1 ])
        assert_equal [], AnswerShuffle.pick(shuffled, [ 0, 1, 3 ])
        assert_equal [], AnswerShuffle.pick(shuffled, [ 0, 1, -1 ])
      end
    end
  end
end
