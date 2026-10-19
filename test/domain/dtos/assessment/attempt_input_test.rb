require "test_helper"

module Dtos
  module Assessment
    class AttemptInputTest < ActiveSupport::TestCase
      def input(**attributes)
        AttemptInput.new(session_public_id: "SeSsIoN0000001", question_id: "12", **attributes)
      end

      test "les propositions cochées deviennent des entiers, sans case vide ni doublon" do
        form = input(answer_ids: [ "", "31", "7", "31", nil ])

        assert form.valid?
        assert_equal [ 31, 7 ], form.answer_ids
        assert_equal 12, form.question_id
      end

      test "une seule proposition, envoyée par un bouton radio, se lit comme une liste" do
        assert_equal [ 4 ], input(answer_ids: "4").answer_ids
      end

      test "rien de coché : « Sélectionne au moins une proposition. »" do
        form = input(answer_ids: [ "" ])

        assert_not form.valid?
        assert_equal [], form.answer_ids
        assert_equal [ I18n.t("activemodel.errors.models.dtos/assessment/attempt_input.attributes.answer_ids.blank") ],
                     form.errors[:answer_ids]
        assert_equal [], input.answer_ids
      end

      test "une proposition qui n'est pas un nombre est ignorée, jamais convertie en 0" do
        assert_equal [ 5 ], input(answer_ids: [ "abc", "5", "0x3" ]).answer_ids
      end

      # ADR-0091 §4.4 : les trous et le nombre envoient du texte ; l'ordre et relier, des indices d'affichage.
      test "un texte saisi suffit, sans proposition ; vide ou trop long, il est refusé" do
        assert input(response_text: "  Abidjan ").valid?
        assert_equal "Abidjan", input(response_text: "  Abidjan ").response_text
        assert input(response_text: " ").invalid?
        assert input(response_text: " ").tap(&:validate).errors.added?(:response_text, :blank)
        assert input(response_text: "x" * 201).tap(&:validate).errors.added?(:response_text, :too_long, count: 200)
        assert_nil input.response_text
        assert_nil input(response_text: nil).response_text
        assert input(response_text: "Abi\0djan").tap(&:validate).errors.added?(:response_text, :invalid, value: "Abi\0djan")
      end

      test "les indices d'affichage gardent leur ordre et leurs doublons ; un indice illisible reste, en -1" do
        form = input(display_order: [ "2", "0", "1", "0", "x", "" ])

        assert form.valid?
        assert_equal [ 2, 0, 1, 0, -1, -1 ], form.display_order
        assert_equal [], input.display_order
      end

      test "la question est exigée" do
        form = AttemptInput.new(session_public_id: "SeSsIoN0000001", answer_ids: [ "1" ])

        assert_not form.valid?
        assert form.errors.added?(:question_id, :blank)
      end
    end
  end
end
