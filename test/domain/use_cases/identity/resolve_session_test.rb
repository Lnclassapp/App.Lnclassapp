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
        def find_by_token_digest(token_digest:)
          @session if token_digest == Entities::Identity::SecretDigest.hmac("token", key: "key")
        end

        def destroy(id:) = @destroyed = id
        def touch(id:, at:) = @touched = [ id, at ]
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        attr_reader :current_school_id

        def actor_for(user_id:, current_school_id: nil)
          @current_school_id = current_school_id
          Entities::Identity::Actor.new(user_id:, role: :team, team_role: "admin")
        end
      end

      def session(role: "student", created_at: NOW - 1.day, last_seen_at: NOW - 1.minute, verified_at: nil, current_school_id: nil)
        Entities::Identity::SessionState.new(id: 5, user_id: 9, role:, created_at:, last_seen_at:, second_factor_verified_at: verified_at,
                                             second_factor_confirmed: true, current_school_id:)
      end

      def resolve(session, token: "token")
        @sessions = FakeSessions.new(session)
        @users = FakeUsers.new
        ResolveSession.new(sessions: @sessions, users: @users, policy: Policies::Identity::SessionPolicy.new, digest_key: "key",
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

      # ADR-0094 §4.2 : l'acteur est construit avec l'établissement courant de la session ; le dépôt le vérifie.
      test "the actor is built with the current school of the session" do
        assert resolve(session(role: "teacher", current_school_id: 42)).success?
        assert_equal 42, @users.current_school_id

        resolve(session(role: "teacher"))
        assert_nil @users.current_school_id
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
