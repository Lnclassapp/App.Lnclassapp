require "test_helper"

module Entities
  module Classroom
    class StudentArrivalChannelTest < ActiveSupport::TestCase
      test "three channels; « code » is written again by the class code (ADR code-de-classe §4.6)" do
        assert_equal %w[standard link code], StudentArrivalChannel::ALL
        assert_equal %w[standard link code], StudentArrivalChannel::WRITABLE
        assert StudentArrivalChannel::ALL.frozen? && StudentArrivalChannel::WRITABLE.frozen?
      end
    end
  end
end
