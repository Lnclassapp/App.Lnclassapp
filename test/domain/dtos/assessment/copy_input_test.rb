require "test_helper"

module Dtos
  module Assessment
    class CopyInputTest < ActiveSupport::TestCase
      def input(answers, session_public_id: "abc") = CopyInput.new(session_public_id:, answers:)

      test "une réponse par question, nil quand elle est restée vide (rien coché, texte blanc, aucun indice)" do
        copy = input({ "1" => { answer_ids: %w[3 4] }, "2" => { answer_ids: [ "" ] }, "3" => { response_text: "  " },
                       "4" => { display_order: [ "", " " ] }, "5" => {}, "6" => { response_text: "12" }, "7" => { display_order: %w[1 0] } })

        assert_predicate copy, :valid?
        assert_equal [ 1, 2, 3, 4, 5, 6, 7 ], copy.answers.keys
        assert_equal [ AttemptInput, NilClass, NilClass, NilClass, NilClass, AttemptInput, AttemptInput ], copy.answers.values.map(&:class)
        assert_equal [ [ 3, 4 ], "12" ], [ copy.answers[1].answer_ids, copy.answers[6].response_text ]
      end

      test "une valeur qui n'est pas une table, ou une clé hors du champ lu, est une question vide" do
        copy = input({ "1" => "x", "2" => { inconnu: "y" } })

        assert_predicate copy, :valid?
        assert_equal [ nil, nil ], copy.answers.values
      end

      test "illisible : pas une table, trop de réponses, clé qui n'est pas un entier" do
        assert_not input("x").valid?
        assert_not input((1..CopyInput::MAX_ANSWERS + 1).to_h { [ it.to_s, {} ] }).valid?
        assert_not input({ "abc" => { answer_ids: [ "1" ] } }).valid?
        assert_not input({}, session_public_id: nil).valid?
      end

      test "une copie sans aucune réponse est valide" do
        assert_predicate input({}), :valid?
      end
    end
  end
end
