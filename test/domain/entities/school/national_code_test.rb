require "test_helper"

module Entities
  module School
    # CP-09 (ADR-0063): the national code of a school — 6 digits, public, printed with the BEPC results.
    class NationalCodeTest < ActiveSupport::TestCase
      test "spaces and dashes are removed; blank is nil" do
        assert_equal "012345", NationalCode.normalize(" 012 345 ")
        assert_equal "012345", NationalCode.normalize("012-345")
        assert_nil NationalCode.normalize("  ")
        assert_nil NationalCode.normalize(nil)
      end

      test "an integer of the import keeps its leading zeros" do
        assert_equal "012345", NationalCode.normalize(12_345)
      end

      test "exactly 6 digits" do
        assert NationalCode.valid?("012345")
        [ "12345", "1234567", "12345a", nil ].each { assert_not NationalCode.valid?(it), it.inspect }
      end
    end

    # CP-11, CP-14: a join request, and the cap of pending requests per school.
    class JoinRequestTest < ActiveSupport::TestCase
      test "only a pending request can be decided" do
        assert JoinRequest.new(id: 1, public_id: "r", teacher_id: 2, school_id: 3, status: "pending", teacher_name: "A").pending?
        assert_not JoinRequest.new(id: 1, public_id: "r", teacher_id: 2, school_id: 3, status: "approved", teacher_name: "A").pending?
      end

      test "at most 5 pending requests per school (default, to be confirmed)" do
        assert_equal 5, JoinRequest::MAX_PENDING_PER_SCHOOL
        assert JoinRequest.room_for_another?(pending_count: 4)
        assert_not JoinRequest.room_for_another?(pending_count: 5)
      end
    end
  end
end
