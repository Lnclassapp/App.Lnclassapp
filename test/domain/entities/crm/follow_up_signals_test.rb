require "test_helper"

# CA-15 to CA-19 (ADR-XXXX contexte crm §4): the four signals of « À relancer », a pure function of what the query read.
module Entities
  module Crm
    class FollowUpSignalsTest < ActiveSupport::TestCase
      TODAY = Date.new(2026, 11, 5)

      def reasons(stage: :prospect, last_activity_on: nil, first_attached_on: nil, last_interaction_on: nil, overdue: false, deactivated: false)
        FollowUpSignals.reasons(stage:, last_activity_on:, first_attached_on:, last_interaction_on:, overdue:, deactivated:, today: TODAY)
      end

      test "a school with nothing to say is not to follow up" do
        assert_empty reasons
      end

      test "CA-15: an overdue open follow-up gives « overdue »" do
        assert_equal [ :overdue ], reasons(overdue: true)
      end

      test "CA-16: last activity between 15 and 60 days ago gives « usage_lost »" do
        assert_equal [ :usage_lost ], reasons(stage: :registered, last_activity_on: TODAY - 20)
        assert_equal [ :usage_lost ], reasons(stage: :registered, last_activity_on: TODAY - 15)
        assert_equal [ :usage_lost ], reasons(stage: :registered, last_activity_on: TODAY - 60)
      end

      test "usage_lost does not apply to a recent activity nor to one older than 60 days" do
        assert_empty reasons(stage: :active, last_activity_on: TODAY - 14)
        assert_empty reasons(stage: :registered, last_activity_on: TODAY - 61)
      end

      test "CA-17: a « demo_done » school without interaction for 7 days gives « demo_stalled »" do
        assert_equal [ :demo_stalled ], reasons(stage: :demo_done, last_interaction_on: TODAY - 8)
        assert_equal [ :demo_stalled ], reasons(stage: :demo_done, last_interaction_on: TODAY - 7)
        assert_equal [ :demo_stalled ], reasons(stage: :demo_done)
      end

      test "demo_stalled needs the demo stage and a silence of 7 days" do
        assert_empty reasons(stage: :demo_done, last_interaction_on: TODAY - 6)
        assert_empty reasons(stage: :prospect, last_interaction_on: TODAY - 30)
      end

      test "CA-18: first attached more than 14 days ago and never active gives « registered_idle »" do
        assert_equal [ :registered_idle ], reasons(stage: :registered, first_attached_on: TODAY - 15)
      end

      test "registered_idle needs more than 14 days and no activity at all" do
        assert_empty reasons(stage: :registered, first_attached_on: TODAY - 14)
        assert_empty reasons(stage: :active, first_attached_on: TODAY - 40, last_activity_on: TODAY - 2)
      end

      test "CA-19: a deactivated school is never to follow up, whatever the signals" do
        assert_empty reasons(overdue: true, deactivated: true, stage: :registered, first_attached_on: TODAY - 40)
      end

      test "CA-19: a school shown as « lost » is never to follow up" do
        assert_empty reasons(stage: :lost, overdue: true, last_activity_on: TODAY - 30)
      end

      test "signals add up, in the order of the page" do
        assert_equal %i[overdue usage_lost], reasons(stage: :registered, overdue: true, last_activity_on: TODAY - 20)
      end

      test "the reasons are the four signals of the ADR, in page order" do
        assert_equal %i[overdue usage_lost demo_stalled registered_idle], FollowUpSignals::REASONS
      end
    end
  end
end
