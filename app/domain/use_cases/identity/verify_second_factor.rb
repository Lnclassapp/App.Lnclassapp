# 🧠 DOMAINE · UseCases::Identity::VerifySecondFactor
# Rôle : vérifie un code TOTP (rejeu refusé) ou un code de secours, puis marque la session vérifiée
# ADR  : 0028, 0031, 0050
module UseCases
  module Identity
    class VerifySecondFactor
      KIND = "second_factor".freeze
      INVALID = { code: [ :invalid ] }.freeze

      def initialize(users:, second_factors:, sessions:, login_attempts:, audit_log:, policy:, digest_key:, clock:)
        @users = users
        @second_factors = second_factors
        @sessions = sessions
        @login_attempts = login_attempts
        @audit_log = audit_log
        @policy = policy
        @digest_key = digest_key
        @clock = clock
      end

      # dto : Dtos::Identity::SecondFactorCodeInput. → success | :forbidden | :invalid | :locked (errors[:retry_after])
      def call(session:, dto:, ip:)
        allowed = @policy.call(actor: nil, session:, step: :verify)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        now = @clock.now
        contact = @users.find(id: session.user_id).contact
        failures = @login_attempts.consecutive_failures(contact:, kind: KIND)
        retry_after = Entities::Identity::Lockout.retry_after(failures: failures.count, last_failed_at: failures.last_failed_at, now:)
        return Shared::Result.failure(:locked, errors: { retry_after: }) if retry_after

        accepted = accept?(session, dto, ip, now)
        @login_attempts.record(contact:, user_id: session.user_id, ip:, succeeded: accepted, kind: KIND, at: now)
        return reject(session, failures.count + 1, ip, now) unless accepted

        @sessions.mark_second_factor_verified(id: session.id, at: now)
        Shared::Result.success
      end

      private

      def accept?(session, dto, ip, now)
        return !@second_factors.verify_code(user_id: session.user_id, code: dto.code, now:).nil? if dto.totp?

        digest = Entities::Identity::SecretDigest.hmac(dto.code, key: @digest_key)
        return false unless @second_factors.consume_backup_code(user_id: session.user_id, code_digest: digest, at: now)

        @audit_log.record(action: "backup_code.used", actor_id: session.user_id, subject_type: "User", subject_id: session.user_id,
                          ip:, at: now)
        true
      end

      def reject(session, failures, ip, now)
        if Entities::Identity::Lockout.tier_reached?(failures)
          @audit_log.record(action: "login.locked", actor_id: nil, subject_type: "User", subject_id: session.user_id,
                            metadata: { kind: KIND, failures: }, ip:, at: now)
        end
        Shared::Result.failure(:invalid, errors: INVALID)
      end
    end
  end
end
