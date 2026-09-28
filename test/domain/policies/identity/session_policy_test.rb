require "test_helper"

module Policies
  module Identity
    class SessionPolicyTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 8)

      def session(verified_at: nil)
        Entities::Identity::SessionState.new(id: 1, user_id: 7, role: "team", created_at: NOW, last_seen_at: NOW,
                                             second_factor_verified_at: verified_at, second_factor_confirmed: true)
      end

      test "le porteur du jeton agit sur sa session" do
        assert SessionPolicy.new.call(actor: nil, session:).success?
        assert SessionPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 7, role: :team), session:).success?
      end

      test "refuse une session absente ou celle d'un autre" do
        assert_equal :forbidden, SessionPolicy.new.call(actor: nil, session: nil).code
        assert_equal :forbidden, SessionPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 8, role: :team), session:).code
      end

      test "l'état de session dit s'il est vérifié et s'il est d'équipe" do
        assert_not session.verified?
        assert session(verified_at: NOW).verified?
        assert session.team?
        assert_not session.with(role: "student").team?
      end

      test "une session est privilégiée pour l'équipe et la direction seulement (ADR-0066 §4.2)" do
        assert session.privileged?
        assert session.with(role: "school_admin").privileged?
        %w[student teacher].each { assert_not session.with(role: it).privileged?, it }
      end
    end
  end
end
