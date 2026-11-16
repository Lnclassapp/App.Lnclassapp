require "test_helper"

module Repositories
  module Communication
    # notifications-push: the adapters of the two Lot 0 ports, against the real tables.
    class PushRepositoriesTest < ActiveSupport::TestCase
      setup do
        @awa = create_student
        @subscriptions = PushSubscriptionRepository.new
        @preferences = PushPreferenceRepository.new
      end

      def register(user: @awa, session: nil, endpoint: "https://push.example.test/a", p256dh: "k1", auth: "a1")
        @subscriptions.register(user_id: user.id, session_id: session&.id, endpoint:, p256dh:, auth:)
      end

      test "register stores the subscription, reads it back and is idempotent per address" do
        session = create_login_session(user: @awa)
        first = register(session:)

        assert_equal [ first ], @subscriptions.for_user(user_id: @awa.id)
        assert_equal session.id, first.session_id

        again = register(session:, p256dh: "k2")

        assert_equal first.id, again.id
        assert_equal "k2", again.p256dh
        assert_equal 1, Orm::Communication::PushSubscription.count
      end

      test "a known address changes owner and loses its failures" do
        kofi = create_student
        row = register
        @subscriptions.record_failure(id: row.id)
        moved = register(user: kofi)

        assert_equal row.id, moved.id
        assert_equal kofi.id, moved.user_id
        assert_equal 0, moved.failure_count
        assert_empty @subscriptions.for_user(user_id: @awa.id)
      end

      test "delete, delete_for_user and delete_for_sessions" do
        session = create_login_session(user: @awa)
        a = register(session:)
        b = register(endpoint: "https://push.example.test/b")
        register(user: create_student, endpoint: "https://push.example.test/c")

        assert_equal 1, @subscriptions.delete_for_sessions(session_ids: [ session.id ])
        assert_equal 1, @subscriptions.delete(id: b.id)
        assert_equal 0, @subscriptions.delete(id: a.id)
        register
        assert_equal 1, @subscriptions.delete_for_user(user_id: @awa.id)
        assert_equal 1, Orm::Communication::PushSubscription.count
      end

      test "success and failure counters" do
        row = register
        at = Time.utc(2026, 11, 16, 12)

        assert_equal 1, @subscriptions.record_failure(id: row.id)
        assert_equal 2, @subscriptions.record_failure(id: row.id)
        assert_equal 0, @subscriptions.record_failure(id: 0)
        @subscriptions.record_success(id: row.id, at:)

        reloaded = @subscriptions.for_user(user_id: @awa.id).first

        assert_equal at, reloaded.last_success_at
        assert_equal 0, reloaded.failure_count
      end

      test "delete_stale removes what has no success since the date, creation included" do
        old = register(endpoint: "https://push.example.test/old")
        Orm::Communication::PushSubscription.where(id: old.id).update_all(created_at: 70.days.ago)
        fresh = register(endpoint: "https://push.example.test/fresh")
        kept = register(endpoint: "https://push.example.test/kept")
        Orm::Communication::PushSubscription.where(id: kept.id).update_all(created_at: 70.days.ago, last_success_at: 2.days.ago)

        assert_equal 1, @subscriptions.delete_stale(before: 60.days.ago)
        assert_equal [ fresh.id, kept.id ].sort, @subscriptions.for_user(user_id: @awa.id).map(&:id).sort
      end

      test "preference: off, on, postponed — each write keeps the other column" do
        at = Time.utc(2026, 11, 16, 12)

        assert_not @preferences.turned_off?(user_id: @awa.id)
        assert_nil @preferences.invitation_postponed_until(user_id: @awa.id)

        @preferences.postpone_invitation(user_id: @awa.id, until_time: at + 7.days)
        @preferences.turn_off(user_id: @awa.id, at:)

        assert @preferences.turned_off?(user_id: @awa.id)
        assert_equal at + 7.days, @preferences.invitation_postponed_until(user_id: @awa.id)

        @preferences.turn_on(user_id: @awa.id)

        assert_not @preferences.turned_off?(user_id: @awa.id)
        assert_equal at + 7.days, @preferences.invitation_postponed_until(user_id: @awa.id)
        assert_equal 1, Orm::Communication::PushPreference.count
      end
    end
  end
end
