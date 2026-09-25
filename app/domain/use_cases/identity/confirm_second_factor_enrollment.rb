# 🧠 DOMAINE · UseCases::Identity::ConfirmSecondFactorEnrollment
# Rôle : confirme le TOTP, émet les codes de secours (montrés une seule fois) et vérifie la session
# ADR  : 0028, 0031
module UseCases
  module Identity
    class ConfirmSecondFactorEnrollment
      INVALID = { code: [ :invalid ] }.freeze

      def initialize(second_factors:, sessions:, audit_log:, transaction:, policy:, digest_key:, clock:)
        @second_factors = second_factors
        @sessions = sessions
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @digest_key = digest_key
        @clock = clock
      end

      # dto : Dtos::Identity::SecondFactorCodeInput. → success([codes de secours en clair]) | :forbidden | :invalid
      def call(session:, dto:)
        allowed = @policy.call(actor: nil, session:, step: :enroll)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?
        return Shared::Result.failure(:invalid, errors: INVALID) unless dto.totp?

        now = @clock.now
        return Shared::Result.failure(:invalid, errors: INVALID) if @second_factors.verify_code(user_id: session.user_id, code: dto.code, now:).nil?

        Shared::Result.success(confirm(session, now))
      end

      private

      def confirm(session, now)
        codes = Entities::Identity::BackupCodes.generate
        digests = codes.map { |code| Entities::Identity::SecretDigest.hmac(code, key: @digest_key) }
        @transaction.call do
          @second_factors.confirm(user_id: session.user_id, backup_code_digests: digests, at: now)
          @sessions.mark_second_factor_verified(id: session.id, at: now)
          @audit_log.record(action: "totp.enrolled", actor_id: session.user_id, subject_type: "User", subject_id: session.user_id, at: now)
        end
        codes
      end
    end
  end
end
