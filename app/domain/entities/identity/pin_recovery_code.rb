# 🧠 DOMAINE · Entities::Identity::PinRecoveryCode
# Rôle : code de récupération du PIN, 8 chiffres, 15 minutes, 5 essais
# ADR  : 0032
module Entities
  module Identity
    PinRecoveryCode = Data.define(:id, :user_id, :code_digest, :expires_at, :failed_attempts, :used_at, :revoked_at) do
      def initialize(id:, user_id:, code_digest:, expires_at:, failed_attempts: 0, used_at: nil, revoked_at: nil)
        super
      end

      def self.generate = format("%0#{PinRecoveryCode::LENGTH}d", SecureRandom.random_number(10**PinRecoveryCode::LENGTH))

      # Un code utilisé, révoqué ou épuisé est :revoked ; un code périmé est :expired.
      def status(now:)
        return :revoked if used_at || revoked_at || failed_attempts >= PinRecoveryCode::MAX_FAILED_ATTEMPTS
        return :expired if now >= expires_at

        :usable
      end
    end
    PinRecoveryCode::TTL = 15.minutes
    PinRecoveryCode::LENGTH = 8
    PinRecoveryCode::MAX_FAILED_ATTEMPTS = 5
  end
end
