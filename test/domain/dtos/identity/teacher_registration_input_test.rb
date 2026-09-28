require "test_helper"

module Dtos
  module Identity
    class TeacherRegistrationInputTest < ActiveSupport::TestCase
      def build(**overrides)
        TeacherRegistrationInput.new(last_name: " Koné ", first_name: "Awa  Marie", gender: "female", contact: "07 01 02 03 04",
                                     pin: "2468", pin_confirmation: "2468", school_code: "k7m-4QZ",
                                     material_slug: "svt", **overrides)
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

      test "CE-01: normalise le code d'établissement et garde la saisie brute pour le re-rendu (ADR-0057)" do
        input = build(school_code: " k7m 4QZ ")

        assert input.valid?
        assert_equal [ "k7m4qz", " k7m 4QZ " ], [ input.school_code, input.raw_school_code ]
      end

      test "exige le code d'établissement et la matière ; plus de DRENA ni d'établissement choisi" do
        found = errors(school_code: " ", material_slug: "")

        assert found.of_kind?(:school_code, :blank)
        assert found.of_kind?(:material_slug, :blank)
        assert errors(school_code: nil).of_kind?(:school_code, :blank)
        assert_empty TeacherRegistrationInput.attribute_names & %w[drena_public_id school_public_id]
      end

      test "CE-04: un code au mauvais format, ou au format d'un code de classe, a chacun son erreur" do
        assert errors(school_code: "k7m4q").of_kind?(:school_code, :invalid)
        assert errors(school_code: "k7m4q0").of_kind?(:school_code, :invalid)
        assert errors(school_code: "KFM 37").of_kind?(:school_code, :classroom_code)
        assert_not errors(school_code: "KFM 37").of_kind?(:school_code, :invalid)
      end

      test "n'a aucun attribut de rôle : un rôle ajouté à la main est refusé" do
        assert_not_includes TeacherRegistrationInput.attribute_names, "role"
        assert_raises(ActiveModel::UnknownAttributeError) { build(role: "team") }
      end
    end
  end
end
