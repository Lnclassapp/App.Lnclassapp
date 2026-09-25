require "test_helper"

module Dtos
  module Identity
    class PinResetInputTest < ActiveSupport::TestCase
      def build(**overrides)
        PinResetInput.new(contact: "07 01 02 03 04", code: "1234 5678", pin: "2468", pin_confirmation: "2468", ip: "1.2.3.4", **overrides)
      end

      test "une saisie complète est valide et normalisée" do
        input = build

        assert input.valid?
        assert_equal "0701020304", input.contact
        assert_equal "12345678", input.code
      end

      test "exige un code à 8 chiffres" do
        assert build(code: "1234567").tap(&:validate).errors.of_kind?(:code, :invalid)
        assert build(code: nil).tap(&:validate).errors.of_kind?(:code, :blank)
      end

      test "exige un PIN au format et sa confirmation identique" do
        assert build(pin: "12a4", pin_confirmation: "12a4").tap(&:validate).errors.of_kind?(:pin, :invalid)
        assert build(pin_confirmation: "1357").tap(&:validate).errors.of_kind?(:pin_confirmation, :confirmation)
        assert build(pin: "").tap(&:validate).errors.of_kind?(:pin, :blank)
      end

      test "exige un contact valide" do
        assert build(contact: "0801020304").tap(&:validate).errors.of_kind?(:contact, :blank)
      end
    end
  end
end
