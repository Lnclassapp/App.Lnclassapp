require "test_helper"

module Entities
  module Identity
    class PinTest < ActiveSupport::TestCase
      test "exige exactement 4 chiffres" do
        assert Pin.valid?("2468")
        assert_not Pin.valid?("246")
        assert_not Pin.valid?("24689")
        assert_not Pin.valid?("24a8")
      end

      test "refuse ce qui n'est pas une chaîne" do
        assert_not Pin.valid?(2468)
        assert_not Pin.valid?(nil)
      end
    end
  end
end
