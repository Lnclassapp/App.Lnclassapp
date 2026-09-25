# 🧠 DOMAINE · UseCases::Identity::VerifySecondFactor
# Rôle : vérifie un code TOTP (rejeu refusé) ou un code de secours, et marque la session vérifiée
# ADR  : 0031, 0050
module UseCases
  module Identity
    class VerifySecondFactor
      KIND = "second_factor".freeze

      def initialize(users:, second_factors:, sessions:, login_attempts:, audit_log:, digest_key:, clock:)
        @users = users
        @second_factors = second_factors
        @sessions = sessions
        @login_attempts = login_attempts
        @audit_log = audit_log
        @digest_key = digest_key
        @clock = clock
      end

      # dto : Dtos::Identity::SecondFactorCodeInput
      def call(user_id:, session_id:, dto:, ip:)
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        user = @users.find(id: user_id)
        return Shared::Result.failure(:not_found) unless user

        now = @clock.now
        failures = @login_attempts.consecutive_failures(contact: user.contact, kind: KIND)
        retry_after = Entities::Identity::Lockout.retry_after(failures: failures.count, last_failed_at: failures.last_failed_at, now:)
        return Shared::Result.failure(:locked, errors: { retry_after: }) if retry_after

        accepted = accept?(user, dto, ip, now)
        @login_attempts.record(contact: user.contact, user_id:, ip:, succeeded: accepted, kind: KIND, at: now)
        return Shared::Result.failure(:invalid, errors: { code: [ :invalid ] }) unless accepted

        @sessions.mark_second_factor_verified(id: session_id, at: now)
        Shared::Result.success
      end

      private

      def accept?(user, dto, ip, now)
        return !@second_factors.verify_code(user_id: user.id, code: dto.code, now:).nil? if dto.totp?

        digest = Entities::Identity::SecretDigest.hmac(dto.code, key: @digest_key)
        return false unless @second_factors.consume_backup_code(user_id: user.id, code_digest: digest, at: now)

        @audit_log.record(action: "backup_code.used", actor_id: user.id, subject_type: "User", subject_id: user.id, ip:, at: now)
        true
      end
    end
  end
end
