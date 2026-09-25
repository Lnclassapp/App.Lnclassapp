require "test_helper"

module Entities
  module Identity
    class InvitationTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)

      def invitation(**overrides)
        Invitation.new(id: 1, kind: "team", contact: "0701020304", team_role: "admin", expires_at: NOW + 1.hour, **overrides)
      end

      test "génère un jeton base58 de 32 caractères" do
        assert_match(/\A[1-9A-HJ-NP-Za-km-z]{32}\z/, Invitation.generate_token)
        assert_equal 72.hours, Invitation::TTL
      end

      test "passe par les quatre statuts" do
        assert_equal :pending, invitation.status(now: NOW)
        assert_equal :expired, invitation(expires_at: NOW).status(now: NOW)
        assert_equal :revoked, invitation(revoked_at: NOW).status(now: NOW)
        assert_equal :accepted, invitation(accepted_at: NOW, revoked_at: NOW).status(now: NOW)
      end

      test "refuse un type inconnu" do
        assert_raises(ArgumentError) { invitation(kind: "parent") }
        assert_nil invitation.school_id
      end
    end
  end
end
