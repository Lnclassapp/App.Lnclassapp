require "test_helper"

module Queries
  module Communication
    # notifications-push: the card shows after a first pass (>= 10/20) only for a student with no subscription, not turned off,
    # not postponed for less than 7 days, outside the Android shell; the profile row follows the subscription and the switch.
    class PushInvitationQueryTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 16, 12)

      setup do
        @student = create_student
        @query = PushInvitationQuery.new
      end

      def show?(score: 60, shell: false) = @query.show?(student_id: @student.id, score_percent: score, shell:, now: NOW)

      test "a first pass shows the card" do
        assert show?
        assert show?(score: 50)
      end

      test "a score under the average does not" do
        assert_not show?(score: 40)
      end

      test "an existing subscription hides it" do
        create_push_subscription(user: @student)

        assert_not show?
      end

      test "a subscription of another student does not" do
        create_push_subscription(user: create_student)

        assert show?
      end

      test "turned off hides it" do
        create_push_preference(user: @student, turned_off_at: NOW - 1.day)

        assert_not show?
      end

      test "later hides it for seven days, then it comes back" do
        create_push_preference(user: @student, invitation_postponed_until: NOW + 4.days)

        assert_not show?

        Orm::Communication::PushPreference.update_all(invitation_postponed_until: NOW - 1.minute)

        assert show?
      end

      test "a preference without switch nor delay keeps the card" do
        create_push_preference(user: @student)

        assert show?
      end

      test "the Android shell never shows it" do
        assert_not show?(shell: true)
      end

      test "profile state" do
        state = ->(shell: false) { @query.profile_state(student_id: @student.id, shell:) }

        assert_equal :hidden, state.call
        create_push_subscription(user: @student)

        assert_equal :on, state.call
        assert_equal :hidden, state.call(shell: true)

        create_push_preference(user: @student, turned_off_at: NOW)

        assert_equal :off, state.call
      end

      test "a postponed-only preference does not open the profile row" do
        create_push_preference(user: @student, invitation_postponed_until: NOW + 1.day)

        assert_equal :hidden, @query.profile_state(student_id: @student.id)
      end
    end
  end
end
