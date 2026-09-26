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

      test "la question est exigée" do
        form = AttemptInput.new(session_public_id: "SeSsIoN0000001", answer_ids: [ "1" ])

        assert_not form.valid?
        assert form.errors.added?(:question_id, :blank)
      end
    end
  end
end
