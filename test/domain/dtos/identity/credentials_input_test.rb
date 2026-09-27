require "test_helper"

module Dtos
  module Identity
    class CredentialsInputTest < ActiveSupport::TestCase
      test "normalise le contact et valide le PIN" do
        input = CredentialsInput.new(contact: "+225 07 01 02 03 04", pin: "2468", ip: "1.2.3.4", user_agent: "UA")

        assert input.valid?
        assert_equal "0701020304", input.contact
        assert_equal "0701020304", input.attempt_key
        assert_equal "+225 07 01 02 03 04", input.raw_contact
      end

      test "un contact invalide devient absent, et garde sa forme brute pour le journal" do
        input = CredentialsInput.new(contact: "0801020304", pin: "2468")

        assert_not input.valid?
        assert input.errors.of_kind?(:contact, :blank)
        assert_equal "0801020304", input.attempt_key
      end

      test "tronque un contact brut à 20 caractères pour le journal" do
        assert_equal 20, CredentialsInput.new(contact: "x" * 40).attempt_key.length
      end

      test "exige un PIN à 4 chiffres" do
        blank = CredentialsInput.new(contact: "0701020304", pin: "")
        wrong = CredentialsInput.new(contact: "0701020304", pin: "12a4")

        assert blank.invalid?
        assert blank.errors.of_kind?(:pin, :blank)
        assert wrong.invalid?
        assert wrong.errors.of_kind?(:pin, :invalid)
      end
    end
  end
end
