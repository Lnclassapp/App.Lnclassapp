# 🧠 DOMAINE · UseCases::Identity::ConfirmSecondFactorEnrollment
# Rôle : confirme le TOTP, émet les codes de secours (affichés une fois) et vérifie la session
# ADR  : 0031
module UseCases
  module Identity
    class ConfirmSecondFactorEnrollment
      def initialize(second_factors:, sessions:, audit_log:, transaction:, digest_key:, clock:)
        @second_factors = second_factors
        @sessions = sessions
        @audit_log = audit_log
        @transaction = transaction
        @digest_key = digest_key
        @clock = clock
      end

      # dto : Dtos::Identity::SecondFactorCodeInput. → success([codes de secours en clair])
      def call(user_id:, session_id:, dto:)
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?
        return Shared::Result.failure(:invalid, errors: { code: [ :invalid ] }) unless dto.totp?

        state = @second_factors.state_for(user_id:)
        return Shared::Result.failure(:conflict, errors: { base: [ :not_enrolling ] }) if state.nil? || state.confirmed

        now = @clock.now
        return Shared::Result.failure(:invalid, errors: { code: [ :invalid ] }) unless @second_factors.verify_code(user_id:, code: dto.code, now:)

        Shared::Result.success(confirm(user_id, session_id, now))
      end

      private

      def confirm(user_id, session_id, now)
        codes = Entities::Identity::BackupCodes.generate
        digests = codes.map { |code| Entities::Identity::SecretDigest.hmac(code, key: @digest_key) }
        @transaction.call do
          @second_factors.confirm(user_id:, backup_code_digests: digests, at: now)
          @sessions.mark_second_factor_verified(id: session_id, at: now)
          @audit_log.record(action: "totp.enrolled", actor_id: user_id, subject_type: "User", subject_id: user_id, at: now)
        end
        codes
      end
    end
  end
end
