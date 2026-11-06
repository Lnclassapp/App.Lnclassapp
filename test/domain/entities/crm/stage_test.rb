require "test_helper"

# ADR-XXXX (contexte crm) §4: the displayed stage crosses what the team typed with what the application knows of the usage.
module Entities
  module Crm
    class StageTest < ActiveSupport::TestCase
      TODAY = Date.new(2026, 11, 5)

      def resolve(saved: nil, accounts_count: 0, last_activity_on: nil)
        Stage.resolve(saved:, accounts_count:, last_activity_on:, today: TODAY)
      end

      test "CA-03: a school without any account and nothing typed is a prospect" do
        assert_equal :prospect, resolve
        assert_equal :prospect, resolve(saved: "prospect")
      end

      test "CA-04: usage in the last 14 days beats a typed « lost »" do
        assert_equal :active, resolve(saved: "lost", accounts_count: 3, last_activity_on: TODAY - 3)
      end

      test "CA-05: « subscribed » beats everything, even 30 days without activity" do
        assert_equal :subscribed, resolve(saved: "subscribed", accounts_count: 2, last_activity_on: TODAY - 30)
        assert_equal :subscribed, resolve(saved: "subscribed", accounts_count: 2, last_activity_on: TODAY - 1)
      end

      test "the active window is 14 days: day 13 is active, day 14 is not" do
        assert_equal :active, resolve(accounts_count: 1, last_activity_on: TODAY - 13)
        assert_equal :registered, resolve(accounts_count: 1, last_activity_on: TODAY - 14)
      end

      test "a typed « lost » beats registered and demo_done once the activity has stopped" do
        assert_equal :lost, resolve(saved: "lost", accounts_count: 2, last_activity_on: TODAY - 40)
      end

      test "an attached account makes the school registered, over a typed demo_done" do
        assert_equal :registered, resolve(accounts_count: 1)
        assert_equal :registered, resolve(saved: "demo_done", accounts_count: 1)
      end

      test "demo_done shows when no account is attached" do
        assert_equal :demo_done, resolve(saved: "demo_done")
      end

      test "only the four judgements can be typed, never « registered » nor « active »" do
        assert_equal %w[prospect demo_done subscribed lost], Stage::TYPEABLE
        assert_equal %i[prospect demo_done registered active subscribed lost], Stage::DISPLAYED
      end

      test "computed stages are the ones the team cannot type" do
        assert Stage.computed?(:active)
        assert Stage.computed?(:registered)
        assert_not Stage.computed?(:lost)
      end
    end
  end
end
