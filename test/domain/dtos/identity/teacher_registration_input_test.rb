require "test_helper"

module Dtos
  module Identity
    class TeacherRegistrationInputTest < ActiveSupport::TestCase
      def build(**overrides)
        TeacherRegistrationInput.new(last_name: " Koné ", first_name: "Awa  Marie", gender: "female", contact: "07 01 02 03 04",
                                     pin: "2468", pin_confirmation: "2468", drena_public_id: "drn-abj1",
                                     school_public_id: "sch-lca", material_slug: "svt", **overrides)
      end

      def errors(**overrides) = build(**overrides).tap(&:validate).errors

      test "une saisie complète est valide, noms et numéro normalisés" do
        input = build

        assert input.valid?
        assert_equal [ "Koné", "Awa Marie", "0701020304", "07 01 02 03 04" ],
                     [ input.last_name, input.first_name, input.contact, input.raw_contact ]
      end

      test "hérite des règles du nom et du prénom" do
        assert_kind_of PersonNameInput, build
        assert errors(last_name: "").of_kind?(:last_name, :blank)
        assert errors(first_name: "Awa 2").of_kind?(:first_name, :invalid)
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
        assert_equal "0501020304", build(contact: "+225 05 01 02 03 04").contact
      end

      test "exige un PIN de 4 chiffres et sa confirmation identique" do
        assert errors(pin: "", pin_confirmation: "").of_kind?(:pin, :blank)
        assert errors(pin: "12a4", pin_confirmation: "12a4").of_kind?(:pin, :invalid)
        assert errors(pin_confirmation: "1357").of_kind?(:pin_confirmation, :confirmation)
      end

      test "exige la DRENA, l'établissement et la matière" do
        found = errors(drena_public_id: " ", school_public_id: nil, material_slug: "")

        assert found.of_kind?(:drena_public_id, :blank)
        assert found.of_kind?(:school_public_id, :blank)
        assert found.of_kind?(:material_slug, :blank)
      end

      test "n'a aucun attribut de rôle : un rôle ajouté à la main est refusé" do
        assert_not_includes TeacherRegistrationInput.attribute_names, "role"
        assert_raises(ActiveModel::UnknownAttributeError) { build(role: "team") }
      end
    end
  end
end
