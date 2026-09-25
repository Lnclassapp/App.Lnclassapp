require "test_helper"

module Entities
  module Identity
    class UserTest < ActiveSupport::TestCase
      def build(**overrides)
        User.new(id: 1, public_id: "abc", last_name: "Kouassi", first_name: "Aya Marie", contact: "0701020304",
                 gender: "female", role: "student", **overrides)
      end

      test "un élève complet est valide" do
        assert build.valid?
      end

      test "normalise les espaces sans toucher à la casse" do
        user = build(last_name: "  N'GUESSAN  ", first_name: " jean   Élie ")

        assert_equal "N'GUESSAN", user.last_name
        assert_equal "jean Élie", user.first_name
        assert_equal "jean Élie N'GUESSAN", user.display_name
      end

      test "accepte un nom nil sans lever" do
        user = build(last_name: nil, first_name: nil)

        assert_nil user.last_name
        assert_nil user.first_name
        assert user.errors.empty?
        assert_not user.valid?
        assert user.errors.of_kind?(:last_name, :blank)
      end

      test "limite le nom à 50 et les prénoms à 80 caractères" do
        assert build(last_name: "a" * 50, first_name: "b" * 80).valid?

        user = build(last_name: "a" * 51, first_name: "b" * 81)
        assert_not user.valid?
        assert user.errors.of_kind?(:last_name, :too_long)
        assert user.errors.of_kind?(:first_name, :too_long)
      end

      test "refuse chiffres et symboles dans un nom" do
        user = build(first_name: "Aya2", last_name: "K@")

        assert_not user.valid?
        assert user.errors.of_kind?(:first_name, :invalid)
        assert user.errors.of_kind?(:last_name, :invalid)
      end

      test "accepte traits d'union et apostrophes typographiques" do
        assert build(last_name: "Yao-N’Dri", first_name: "Marie-Ange").valid?
      end

      test "exige un genre, un rôle et un contact au format" do
        user = build(gender: "other", role: "parent", contact: "0801020304")

        assert_not user.valid?
        assert user.errors.of_kind?(:gender, :inclusion)
        assert user.errors.of_kind?(:role, :inclusion)
        assert user.errors.of_kind?(:contact, :invalid)
      end

      test "un compte anonymisé n'a plus de contact" do
        user = build(contact: nil, anonymized_at: Time.utc(2026, 9, 25))

        assert user.valid?
        assert user.anonymized?
        assert_not build.anonymized?
      end

      test "un compte team exige un sous-rôle, les autres n'en ont pas" do
        assert build(role: "team", team_role: "admin").valid?
        assert build(role: "team", team_role: "admin").team?
        assert build.student?

        assert build(role: "team", team_role: nil).invalid?
        assert build(role: "team", team_role: "boss").invalid?
        assert build(role: "teacher", team_role: "admin").invalid?
      end
    end
  end
end
