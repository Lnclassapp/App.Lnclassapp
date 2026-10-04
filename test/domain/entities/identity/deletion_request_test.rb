require "test_helper"

module Entities
  module Identity
    # ADR-0036, amendment (2): a request is due 30 days after its reception; amber when 5 days or fewer are left (from the
    # 25th day), late beyond 30 days. Read when displayed, never stored.
    class DeletionRequestTest < ActiveSupport::TestCase
      RECEIVED = Date.new(2026, 9, 1)

      def stage(day) = DeletionRequest.stage(requested_on: RECEIVED, today: RECEIVED + day)

      test "the request is due 30 days after its reception" do
        request = DeletionRequest.new(id: 1, user_id: 2, requested_on: RECEIVED, status: "pending")

        assert_equal Date.new(2026, 10, 1), request.due_on
        assert_equal :soon, request.stage(Date.new(2026, 9, 26))
        assert request.pending?
        assert_not request.with(status: "processed").pending?
      end

      test "on time until the 24th day, soon from the 25th to the 30th, late from the 31st" do
        assert_equal [ :on_time, :on_time, :soon, :soon, :late, :late ], [ 0, 24, 25, 30, 31, 60 ].map { stage(it) }
      end
    end
  end
end
