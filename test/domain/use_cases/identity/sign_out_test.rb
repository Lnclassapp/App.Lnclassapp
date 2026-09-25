require "test_helper"

module UseCases
  module Identity
    class SignOutTest < ActiveSupport::TestCase
      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :destroyed

        def find_by_token_digest(token_digest:)
          Session.new(id: 3, user_id: 1, role: "student", created_at: nil, last_seen_at: nil, second_factor_verified_at: nil) if
            token_digest == Entities::Identity::SecretDigest.hmac("token", key: "key")
        end

        def destroy(id:) = @destroyed = id
      end

      setup { @sessions = FakeSessions.new }

      def sign_out(token) = SignOut.new(sessions: @sessions, digest_key: "key").call(token:)

      test "détruit la session du jeton" do
        assert sign_out("token").success?
        assert_equal 3, @sessions.destroyed
      end

      test "est idempotent sans jeton ou sur un jeton inconnu" do
        assert sign_out(nil).success?
        assert sign_out("autre").success?
        assert_nil @sessions.destroyed
      end
    end
  end
end
