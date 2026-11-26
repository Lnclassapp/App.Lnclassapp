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

      test "reset_failures puts the counter back to zero" do
        row = register
        2.times { @subscriptions.record_failure(id: row.id) }

        assert_equal 1, @subscriptions.reset_failures(id: row.id)
        assert_equal 0, @subscriptions.for_user(user_id: @awa.id).first.failure_count
        assert_equal 1, @subscriptions.record_failure(id: row.id)
      end

      test "delete_stale removes what has no success since the date, registration included" do
        old = register(endpoint: "https://push.example.test/old")
        Orm::Communication::PushSubscription.where(id: old.id).update_all(updated_at: 70.days.ago)
        fresh = register(endpoint: "https://push.example.test/fresh")
        kept = register(endpoint: "https://push.example.test/kept")
        Orm::Communication::PushSubscription.where(id: kept.id).update_all(updated_at: 70.days.ago, last_success_at: 2.days.ago)

        assert_equal 1, @subscriptions.delete_stale(before: 60.days.ago)
        assert_equal [ fresh.id, kept.id ].sort, @subscriptions.for_user(user_id: @awa.id).map(&:id).sort
      end

      test "a subscription created 61 days ago and registered again yesterday is kept, never seen again it is purged" do
        now = Time.utc(2026, 11, 16, 12)
        again = register(endpoint: "https://push.example.test/again")
        never = register(endpoint: "https://push.example.test/never")
        Orm::Communication::PushSubscription.where(id: [ again.id, never.id ]).update_all(created_at: now - 61.days, updated_at: now - 61.days)
        travel_to(now - 1.day) { register(endpoint: "https://push.example.test/again") }

        assert_equal 1, @subscriptions.delete_stale(before: now - 60.days)
        assert_equal [ again.id ], @subscriptions.for_user(user_id: @awa.id).map(&:id)
      end

      test "the purge limit is 60 days: 60 kept, 61 removed" do
        now = Time.utc(2026, 11, 16, 12)
        sixty = register(endpoint: "https://push.example.test/sixty")
        sixty_one = register(endpoint: "https://push.example.test/sixtyone")
        Orm::Communication::PushSubscription.where(id: sixty.id).update_all(updated_at: now - 60.days)
        Orm::Communication::PushSubscription.where(id: sixty_one.id).update_all(updated_at: now - 61.days)

        assert_equal 1, @subscriptions.delete_stale(before: now - 60.days)
        assert_equal [ sixty.id ], @subscriptions.for_user(user_id: @awa.id).map(&:id)
      end

      test "delete_oldest_beyond keeps the most recently registered ones of that student only" do
        rows = (1..6).map { |index| register(endpoint: "https://push.example.test/n#{index}") }
        other = register(user: create_student, endpoint: "https://push.example.test/other")
        rows.each_with_index { |row, index| Orm::Communication::PushSubscription.where(id: row.id).update_all(updated_at: (10 - index).days.ago) }
        travel_to(1.hour.ago) { register(endpoint: "https://push.example.test/n1") }

        assert_equal 1, @subscriptions.delete_oldest_beyond(user_id: @awa.id, limit: 5)
        assert_equal (rows.map(&:id) - [ rows[1].id ]).sort, @subscriptions.for_user(user_id: @awa.id).map(&:id).sort
        assert Orm::Communication::PushSubscription.exists?(other.id)
        assert_equal 0, @subscriptions.delete_oldest_beyond(user_id: @awa.id, limit: 5)
      end

      test "reattach_session moves a session's subscriptions, delete_for_user_except_session keeps only that session's" do
        old = create_login_session(user: @awa)
        fresh = create_login_session(user: @awa)
        mine = register(session: old, endpoint: "https://push.example.test/mine")
        register(session: create_login_session(user: @awa), endpoint: "https://push.example.test/other")
        register(session: nil, endpoint: "https://push.example.test/expired")
        stranger = register(user: create_student, endpoint: "https://push.example.test/stranger")

        assert_equal 1, @subscriptions.reattach_session(from_session_id: old.id, to_session_id: fresh.id)
        assert_equal 2, @subscriptions.delete_for_user_except_session(user_id: @awa.id, session_id: fresh.id)
        assert_equal [ mine.id ], @subscriptions.for_user(user_id: @awa.id).map(&:id)
        assert_equal fresh.id, @subscriptions.for_user(user_id: @awa.id).first.session_id
        assert_equal [ stranger.id ], @subscriptions.for_user(user_id: stranger.user_id).map(&:id)
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
