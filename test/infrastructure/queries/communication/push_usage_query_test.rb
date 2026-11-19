require "test_helper"

module Queries
  module Communication
    # notifications-push, UDR §3.4: the team reads how many students are subscribed, how many turned it off and what was sent
    # this week by motive, in a fixed number of queries, with no name.
    class PushUsageQueryTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 16, 12)

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end

      def usage = PushUsageQuery.new.call(now: NOW)

      test "an empty platform reads zeros and no motive" do
        result = usage

        assert_equal [ 0, 0, 0, 0, 0 ], [ result.students, result.subscriptions, result.turned_off, result.sent, result.failed ]
        assert_empty result.by_motive
      end

      test "counts subscribed students once, their subscriptions, and the students who turned it off" do
        two = create_student
        one = create_student
        create_push_subscription(user: two)
        create_push_subscription(user: two)
        create_push_subscription(user: one)
        create_push_preference(user: two, turned_off_at: NOW - 1.day)
        create_push_preference(user: one)

        result = usage

        assert_equal [ 2, 3, 1 ], [ result.students, result.subscriptions, result.turned_off ]
      end

      test "counts this week's deliveries: sent and failed (failed or gone), by motive, ignoring older and provisional ones" do
        student = create_student
        delivery = ->(motive, status, at = NOW - 1.day) { create_push_delivery(user: student, motive:, status:, sent_at: at) }
        delivery.call("inactive", "delivered")
        delivery.call("inactive", "delivered")
        delivery.call("result", "delivered")
        delivery.call("result", "failed")
        delivery.call("announcement", "gone")
        delivery.call("quiz_prep", "retry")
        delivery.call("unfinished", "disabled")
        delivery.call("assignment_due", "delivered", NOW - 8.days)

        result = usage

        assert_equal [ 3, 2 ], [ result.sent, result.failed ]
        assert_equal({ "inactive" => 2, "result" => 1 }, result.by_motive)
      end

      test "runs a fixed number of queries whatever the data, and exposes no name" do
        before = count_queries { usage }
        3.times do
          student = create_student
          create_push_subscription(user: student)
          create_push_delivery(user: student)
        end

        assert_equal 3, before
        assert_equal before, count_queries { usage }
        assert_equal %i[by_motive failed sent students subscriptions turned_off], PushUsageQuery::Usage.members.sort
      end
    end
  end
end
