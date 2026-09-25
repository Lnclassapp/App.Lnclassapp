require "test_helper"

module UseCases
  module Identity
    class ResolveSessionTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :destroyed, :touched

        def initialize(session) = @session = session
        def find_by_token_digest(token_digest:) = (@session if token_digest == Entities::Identity::SecretDigest.hmac("token", key: "key"))
        def destroy(id:) = @destroyed = id
        def touch(id:, at:) = @touched = [ id, at ]
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def actor_for(user_id:) = Entities::Identity::Actor.new(user_id:, role: :team, team_role: "admin")
      end

      def session(role: "student", created_at: NOW - 1.day, last_seen_at: NOW - 1.minute, verified_at: nil)
        Entities::Identity::SessionState.new(id: 5, user_id: 9, role:, created_at:, last_seen_at:, second_factor_verified_at: verified_at,
                                             second_factor_confirmed: true)
      end

      def resolve(session, token: "token")
        @sessions = FakeSessions.new(session)
        ResolveSession.new(sessions: @sessions, users: FakeUsers.new, policy: Policies::Identity::SessionPolicy.new, digest_key: "key",
                           clock: Clock.new(NOW)).call(token:)
      end

      test "a missing or unknown token is refused by the session policy" do
        assert_equal :forbidden, resolve(session, token: nil).code
        assert_equal :forbidden, resolve(session, token: "autre").code
        assert_equal :forbidden, resolve(nil).code
      end

      test "a session idle for 30 days is destroyed and expired" do
        result = resolve(session(last_seen_at: NOW - 30.days))

        assert_equal :expired, result.code
        assert_equal 5, @sessions.destroyed
      end

      test "a team session older than 12 hours is expired" do
        assert_equal :expired, resolve(session(role: "team", created_at: NOW - 12.hours, verified_at: NOW - 12.hours)).code
      end

      test "a recent session is not rewritten" do
        result = resolve(session)

        assert result.success?
        assert_nil @sessions.touched
        assert_equal 9, result.value.actor.user_id
        assert_equal 5, result.value.session.id
      end

      test "after 5 minutes the last visit is rewritten" do
        resolve(session(last_seen_at: NOW - 5.minutes))

        assert_equal [ 5, NOW ], @sessions.touched
      end

      test "a team account without a verified second factor gets no actor" do
        result = resolve(session(role: "team", created_at: NOW - 1.hour))

        assert result.success?
        assert_nil result.value.actor
        assert_equal 9, result.value.session.user_id
      end

      test "a verified team account gets its actor" do
        assert resolve(session(role: "team", created_at: NOW - 1.hour, verified_at: NOW - 1.hour)).value.actor.team?
      end
    end
  end
end
