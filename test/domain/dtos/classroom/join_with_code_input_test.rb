require "test_helper"

module Dtos
  module Classroom
    class JoinWithCodeInputTest < ActiveSupport::TestCase
      def build(**overrides)
        JoinWithCodeInput.new(last_name: " Kouassi ", first_name: "Aya  Marie", gender: "female", contact: "07 01 02 03 04",
                              pin: "4821", pin_confirmation: "4821", **overrides)
      end

      def errors(**overrides) = build(**overrides).tap(&:validate).errors

      test "une saisie complète est valide, noms et numéro normalisés" do
        input = build

        assert input.valid?
        assert_equal [ "Kouassi", "Aya Marie", "0701020304", "07 01 02 03 04" ],
                     [ input.last_name, input.first_name, input.contact, input.raw_contact ]
      end

      test "hérite des règles du nom et du prénom" do
        assert_kind_of Dtos::Identity::PersonNameInput, build
        assert errors(last_name: "").of_kind?(:last_name, :blank)
        assert errors(first_name: "Aya 2").of_kind?(:first_name, :invalid)
      end

      test "exige un genre connu" do
        assert errors(gender: nil).of_kind?(:gender, :inclusion)
        assert errors(gender: "other").of_kind?(:gender, :inclusion)
        assert build(gender: "male").valid?
      end

      test "distingue un numéro absent d'un numéro invalide" do
        assert errors(contact: "").of_kind?(:contact, :blank)
        assert errors(contact: nil).of_kind?(:contact, :blank)
        assert errors(contact: "0801020304").of_kind?(:contact, :invalid)
        assert_not errors(contact: "0801020304").of_kind?(:contact, :blank)
        assert_equal "0101020304", build(contact: "+225 01 01 02 03 04").contact
      end

      test "Sécurité n° 5 : le PIN est obligatoire, jamais dérivé du numéro, et confirmé à l'identique" do
        assert errors(pin: "", pin_confirmation: "").of_kind?(:pin, :blank)
        assert errors(pin: nil, pin_confirmation: nil).of_kind?(:pin, :blank)
        assert errors(pin: "12a4", pin_confirmation: "12a4").of_kind?(:pin, :invalid)
        assert errors(pin_confirmation: "1357").of_kind?(:pin_confirmation, :confirmation)
        assert_nil build(pin: "").pin.presence
      end

      test "n'a aucun attribut de rôle : un rôle ajouté à la main est refusé" do
        assert_not_includes JoinWithCodeInput.attribute_names, "role"
        assert_raises(ActiveModel::UnknownAttributeError) { build(role: "team") }
      end
    end
  end
end
