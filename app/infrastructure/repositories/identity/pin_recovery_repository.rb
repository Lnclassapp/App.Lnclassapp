# 🔌 INFRA · Repositories::Identity::PinRecoveryRepository
# Rôle : codes de récupération du PIN (empreinte seulement), un seul actif par compte
# ADR  : 0032
module Repositories
  module Identity
    class PinRecoveryRepository
      include Ports::Identity::PinRecoveryRepositoryPort

      def issue(user_id:, issued_by_id:, code_digest:, expires_at:, at:)
        active(user_id).update_all(revoked_at: at)
        Orm::PinRecoveryCode.create!(user_id:, issued_by_id:, code_digest:, expires_at:, created_at: at)
        true
      end

      def active_for(user_id:)
        record = active(user_id).first
        return if record.nil?

        Entities::Identity::PinRecoveryCode.new(
          id: record.id, user_id: record.user_id, code_digest: record.code_digest, expires_at: record.expires_at,
          failed_attempts: record.failed_attempts, used_at: record.used_at, revoked_at: record.revoked_at
        )
      end

      def record_failure(id:, at:)
        code = Orm::PinRecoveryCode.where(id:)
        code.update_all("failed_attempts = failed_attempts + 1")
        code.where(revoked_at: nil).where(failed_attempts: Entities::Identity::PinRecoveryCode::MAX_FAILED_ATTEMPTS..)
            .update_all(revoked_at: at)
        code.pick(:failed_attempts)
      end

      def consume(id:, at:)
        Orm::PinRecoveryCode.where(id:).update_all(used_at: at)
        true
      end

      private

      def active(user_id) = Orm::PinRecoveryCode.where(user_id:, used_at: nil, revoked_at: nil)
    end
  end
end
