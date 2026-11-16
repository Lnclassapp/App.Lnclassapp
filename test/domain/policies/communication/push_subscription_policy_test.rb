require "test_helper"

module Policies
  module Communication
    # notifications-push: only a student, not anonymized, acts on their own notifications.
    class PushSubscriptionPolicyTest < ActiveSupport::TestCase
      def actor(role = :student, user_id: 5) = Entities::Identity::Actor.new(user_id:, role:)
      def user(id: 5, anonymized_at: nil) = Entities::Identity::User.new(id:, role: "student", anonymized_at:)
      def call(actor:, user:) = PushSubscriptionPolicy.new.call(actor:, user:)

      test "a student acts on themselves" do
        assert_predicate call(actor: actor, user: user), :success?
      end

      test "a teacher is refused" do
        assert_equal :forbidden, call(actor: actor(:teacher), user: user).code
      end

      test "a visitor or a missing account is refused" do
        assert_equal :forbidden, call(actor: nil, user: user).code
        assert_equal :forbidden, call(actor: actor, user: nil).code
      end

      test "an anonymized student is refused" do
        assert_equal :forbidden, call(actor: actor, user: user(anonymized_at: Time.utc(2026, 11, 1))).code
      end

      test "another account is refused" do
        assert_equal :forbidden, call(actor: actor, user: user(id: 6)).code
      end
    end
  end
end
