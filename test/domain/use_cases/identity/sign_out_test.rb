require "test_helper"

module UseCases
  module Identity
    class SignOutTest < ActiveSupport::TestCase
      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :destroyed

        def initialize(session) = @session = session
        def find_by_token_digest(token_digest:)
          @session if token_digest == Entities::Identity::SecretDigest.hmac("token", key: "key")
        end

        def destroy(id:) = @destroyed = id
      end

      def sign_out(token, session: Entities::Identity::SessionState.new(id: 5, user_id: 9, role: "student", created_at: nil,
                                                                        last_seen_at: nil, second_factor_verified_at: nil,
                                                                        second_factor_confirmed: false))
        @sessions = FakeSessions.new(session)
        SignOut.new(sessions: @sessions, policy: Policies::Identity::SessionPolicy.new, digest_key: "key").call(token:)
      end

      test "destroys the session of the token" do
        assert sign_out("token").success?
        assert_equal 5, @sessions.destroyed
      end

      test "is idempotent: an unknown or missing token succeeds without destroying anything" do
        assert sign_out("autre").success?
        assert sign_out(nil).success?
        assert_nil @sessions.destroyed
      end
    end
  end
end
