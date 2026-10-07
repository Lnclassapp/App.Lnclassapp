require "test_helper"

module Dtos
  module School
    # IE-18 (ADR-0082 §4.3, UDR-0078 §3.9): on the waiting screen, an unattached teacher chooses a DRENA, then one of its
    # schools; no school code any more.
    class SchoolJoinInputTest < ActiveSupport::TestCase
      def input(**) = SchoolJoinInput.new(**)
      def errors(**) = input(**).tap(&:validate).errors

      test "IE-18 : la DRENA et l'établissement choisis, par leurs identifiants publics" do
        join = input(drena_public_id: "drena-abidjan-1", school_public_id: "sch_7Kq2")

        assert join.valid?
        assert_equal({ drena_public_id: "drena-abidjan-1", school_public_id: "sch_7Kq2" }, join.to_h)
      end

      test "IE-18 : plus aucun code d'établissement" do
        assert_not_respond_to input, :school_code
        assert_raises(ActiveModel::UnknownAttributeError) { input(school_code: "k7m4qz") }
      end

      test "une DRENA ou un établissement absent : blank sous son champ" do
        assert errors(school_public_id: "sch-1").of_kind?(:drena_public_id, :blank)
        assert errors(drena_public_id: "drena-1").of_kind?(:school_public_id, :blank)
        assert errors(drena_public_id: "drena-1", school_public_id: "").of_kind?(:school_public_id, :blank)
      end

      test "un identifiant forgé (octet nul, espaces, trop long) est oublié avant la base" do
        join = input(drena_public_id: "drena 1", school_public_id: "sch\u00001")

        assert_nil join.drena_public_id
        assert_nil join.school_public_id
        assert_nil input(school_public_id: "x" * 65).school_public_id
        assert join.tap(&:validate).errors.of_kind?(:school_public_id, :blank)
      end

      test "les messages : choix manquants et établissement refusé, neutre" do
        assert_equal [ "Choisissez votre DRENA." ], errors(school_public_id: "sch-1").messages_for(:drena_public_id)
        assert_equal [ "Choisissez votre établissement." ], errors(drena_public_id: "drena-1").messages_for(:school_public_id)
        assert_equal "Cet établissement ne peut pas être rejoint.",
                     input.errors.generate_message(:school_public_id, :inclusion)
      end
    end
  end
end
