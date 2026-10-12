require "test_helper"

module Entities
  module Classroom
    class StudentArrivalChannelTest < ActiveSupport::TestCase
      test "three channels, and code is history: no new membership writes it" do
        assert_equal %w[standard link code], StudentArrivalChannel::ALL
        assert_equal %w[standard link], StudentArrivalChannel::WRITABLE
        assert StudentArrivalChannel::ALL.frozen? && StudentArrivalChannel::WRITABLE.frozen?
      end
    end
  end
end
