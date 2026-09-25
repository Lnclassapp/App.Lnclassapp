require "test_helper"

module Entities
  module Identity
    class PinRecoveryCodeTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)

      def code(**overrides) = PinRecoveryCode.new(id: 1, user_id: 2, code_digest: "d", expires_at: NOW + 1.minute, **overrides)

      test "génère 8 chiffres" do
        assert_match(/\A\d{8}\z/, PinRecoveryCode.generate)
        assert_equal 15.minutes, PinRecoveryCode::TTL
      end

      test "un code frais est utilisable" do
        assert_equal :usable, code.status(now: NOW)
        assert_equal 0, code.failed_attempts
      end

      test "un code périmé est expiré" do
        assert_equal :expired, code(expires_at: NOW).status(now: NOW)
      end

      test "un code utilisé, révoqué ou épuisé est révoqué, même périmé" do
        assert_equal :revoked, code(used_at: NOW).status(now: NOW)
        assert_equal :revoked, code(revoked_at: NOW).status(now: NOW)
        assert_equal :revoked, code(failed_attempts: 5, expires_at: NOW - 1.hour).status(now: NOW)
        assert_equal :usable, code(failed_attempts: 4).status(now: NOW)
      end
    end
  end
end
