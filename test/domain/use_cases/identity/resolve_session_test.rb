require "test_helper"

module UseCases
  module Identity
    class ResolveSessionTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      Session = Ports::Identity::SessionRepositoryPort::Session

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :destroyed, :touched

        def initialize(session, key:)
          @session = session
          @digest = Entities::Identity::SecretDigest.hmac("token", key:)
        end

        def find_by_token_digest(token_digest:) = (@session if token_digest == @digest)
        def destroy(id:) = @destroyed = id
        def touch(id:, at:) = @touched = [ id, at ]
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def actor_for(user_id:) = Entities::Identity::Actor.new(user_id:, role: :team, team_role: "admin")
      end

      def session(role: "student", created_at: NOW - 1.day, last_seen_at: NOW - 1.minute, verified_at: nil)
        Session.new(id: 5, user_id: 9, role:, created_at:, last_seen_at:, second_factor_verified_at: verified_at)
      end

      def resolve(session, token: "token")
        @sessions = FakeSessions.new(session, key: "key")
        ResolveSession.new(sessions: @sessions, users: FakeUsers.new, digest_key: "key", clock: Clock.new(NOW)).call(token:)
      end

      test "un jeton absent ou inconnu est :expired" do
        assert_equal :expired, resolve(session, token: nil).code
        assert_equal :expired, resolve(session, token: "autre").code
        assert_equal :expired, resolve(nil).code
      end

      test "une session périmée est détruite puis :expired" do
        result = resolve(session(last_seen_at: NOW - 31.days))

        assert_equal :expired, result.code
        assert_equal 5, @sessions.destroyed
      end

      test "une session récente n'est pas réécrite" do
        result = resolve(session)

        assert result.success?
        assert_nil @sessions.touched
        assert_equal 9, result.value.actor.user_id
        assert_equal :student, result.value.role
        assert_equal 5, result.value.session_id
      end

      test "au-delà de 5 minutes, la dernière visite est réécrite" do
        resolve(session(last_seen_at: NOW - 6.minutes))

        assert_equal [ 5, NOW ], @sessions.touched
      end

      test "un compte team sans second facteur vérifié n'obtient pas d'acteur" do
        result = resolve(session(role: "team", created_at: NOW - 1.hour))

        assert result.success?
        assert_nil result.value.actor
        assert_equal 9, result.value.user_id
        assert_not result.value.second_factor_verified
      end

      test "un compte team vérifié obtient son acteur" do
        result = resolve(session(role: "team", created_at: NOW - 1.hour, verified_at: NOW - 1.hour))

        assert result.value.second_factor_verified
        assert result.value.actor.team?
      end
    end
  end
end
