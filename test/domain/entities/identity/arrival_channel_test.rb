require "test_helper"

module Entities
  module Identity
    # ADR-0083 §4.2: the arrival channel of a teacher. « code » is historical: read, never written again.
    class ArrivalChannelTest < ActiveSupport::TestCase
      test "five channels are read, four are written, code is no longer written" do
        assert_equal %w[standard colleague direction team code], ArrivalChannel::ALL
        assert_equal %w[standard colleague direction team], ArrivalChannel::WRITABLE
        assert_not_includes ArrivalChannel::WRITABLE, "code"
        assert ArrivalChannel::ALL.frozen?
        assert ArrivalChannel::WRITABLE.frozen?
      end
    end
  end
end
