require "test_helper"

module Dtos
  module Identity
    class SecondFactorCodeInputTest < ActiveSupport::TestCase
      test "accepte un code TOTP à 6 chiffres, espaces retirés" do
        input = SecondFactorCodeInput.new(code: "123 456")

        assert input.valid?
        assert input.totp?
        assert_not input.backup_code?
        assert_equal "123456", input.code
      end

      test "accepte un code de secours base58" do
        input = SecondFactorCodeInput.new(code: "abcDEF2345")

        assert input.valid?
        assert input.backup_code?
        assert_not input.totp?
      end

      test "refuse un code absent ou mal formé" do
        assert SecondFactorCodeInput.new(code: nil).invalid?
        assert SecondFactorCodeInput.new(code: "").tap(&:validate).errors.of_kind?(:code, :blank)
        assert SecondFactorCodeInput.new(code: "12345").tap(&:validate).errors.of_kind?(:code, :invalid)
        assert SecondFactorCodeInput.new(code: "abcDEF234O").invalid?
      end
    end
  end
end
