require "test_helper"

# ADR-0077, UDR-0070 §3.1: the form of the direction registration — the person, the number, the school code and the PIN;
# neither role nor subject.
module Dtos
  module Identity
    class SchoolStaffRegistrationInputTest < ActiveSupport::TestCase
      def build(**overrides)
        SchoolStaffRegistrationInput.new(last_name: " Kouassi ", first_name: "Aya  Marie", gender: "female",
                                         contact: "07 01 02 03 04", pin: "2468", pin_confirmation: "2468",
                                         school_code: "k7m-4QZ", **overrides)
      end

      def errors(**overrides) = build(**overrides).tap(&:validate).errors

      test "une saisie complète est valide, noms, numéro et code normalisés, saisies brutes gardées" do
        input = build(school_code: " k7m 4QZ ")

        assert input.valid?
        assert_equal [ "Kouassi", "Aya Marie", "0701020304", "07 01 02 03 04", "k7m4qz", " k7m 4QZ " ],
                     [ input.last_name, input.first_name, input.contact, input.raw_contact, input.school_code, input.raw_school_code ]
      end

      test "hérite des règles du nom et exige un genre connu" do
        assert_kind_of PersonNameInput, build
        assert errors(last_name: "").of_kind?(:last_name, :blank)
        assert errors(gender: "other").of_kind?(:gender, :inclusion)
      end

      test "distingue un numéro absent d'un numéro invalide" do
        assert errors(contact: "").of_kind?(:contact, :blank)
        assert errors(contact: "0801020304").of_kind?(:contact, :invalid)
        assert_not errors(contact: "0801020304").of_kind?(:contact, :blank)
      end

      test "exige un PIN de 4 chiffres et sa confirmation identique" do
        assert errors(pin: "", pin_confirmation: "").of_kind?(:pin, :blank)
        assert errors(pin: "12a4", pin_confirmation: "12a4").of_kind?(:pin, :invalid)
        assert errors(pin_confirmation: "1357").of_kind?(:pin_confirmation, :confirmation)
      end

      test "un code absent, mal formé ou de classe a chacun son erreur" do
        assert errors(school_code: " ").of_kind?(:school_code, :blank)
        assert errors(school_code: "k7m4q").of_kind?(:school_code, :invalid)
        assert errors(school_code: "KFM 37").of_kind?(:school_code, :classroom_code)
        assert_not errors(school_code: "KFM 37").of_kind?(:school_code, :invalid)
      end

      test "n'a ni rôle ni matière" do
        assert_empty SchoolStaffRegistrationInput.attribute_names & %w[role team_role material_slug ref]
        assert_raises(ActiveModel::UnknownAttributeError) { build(role: "team") }
      end
    end
  end
end
