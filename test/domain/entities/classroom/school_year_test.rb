require "test_helper"

module Entities
  module Classroom
    class SchoolYearTest < ActiveSupport::TestCase
      test "l'année commence le 1er septembre" do
        assert_equal "2026-2027", SchoolYear.current(Date.new(2027, 8, 31))
        assert_equal "2027-2028", SchoolYear.current(Date.new(2027, 9, 1))
        assert_equal "2026-2027", SchoolYear.current(Date.new(2026, 10, 1))
      end

      test "valide le format AAAA-AAAA à années consécutives" do
        assert SchoolYear.valid?("2026-2027")
        assert_not SchoolYear.valid?("2026-2028")
        assert_not SchoolYear.valid?("2026/2027")
        assert_not SchoolYear.valid?(nil)
      end
    end
  end
end
