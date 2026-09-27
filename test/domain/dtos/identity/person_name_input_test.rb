require "test_helper"

module Dtos
  module Identity
    class PersonNameInputTest < ActiveSupport::TestCase
      class RegistrationInput < PersonNameInput
        attribute :pin, :string
      end

      test "normalise les espaces sans changer la casse" do
        input = RegistrationInput.new(last_name: "  KONÉ ", first_name: "aya   marie")

        assert input.valid?
        assert_equal "KONÉ", input.last_name
        assert_equal "aya marie", input.first_name
      end

      test "exige les deux champs" do
        input = RegistrationInput.new(last_name: nil, first_name: nil)

        assert_not input.valid?
        assert input.errors.of_kind?(:last_name, :blank)
        assert input.errors.of_kind?(:first_name, :blank)
        assert_nil input.first_name
      end

      test "limite les longueurs et refuse les chiffres" do
        input = RegistrationInput.new(last_name: "a" * 51, first_name: "Aya 2")

        assert_not input.valid?
        assert input.errors.of_kind?(:last_name, :too_long)
        assert input.errors.of_kind?(:first_name, :invalid)
        assert RegistrationInput.new(last_name: "a" * 50, first_name: "b" * 80).valid?
        assert RegistrationInput.new(last_name: "a", first_name: "b" * 81).invalid?
      end
    end
  end
end
