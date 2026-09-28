require "test_helper"

module Entities
  module Identity
    # CP-15 (ADR-0063): the « Ambassadeur » badge, a lever without money, from 3 colleagues signed up (default, to be confirmed).
    class AmbassadorTest < ActiveSupport::TestCase
      test "from 3 referees" do
        assert_equal 3, Ambassador::THRESHOLD
        assert_not Ambassador.ambassador?(referred_count: 2)
        assert Ambassador.ambassador?(referred_count: 3)
      end
    end
  end
end
