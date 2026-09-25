# 🧠 DOMAINE · UseCases::Identity::ResetPinWithCode
# Rôle : nouveau PIN par code de récupération ; coupe toutes les sessions et lève le verrouillage
# ADR  : 0028 (exempté de policy : le visiteur n'est pas connecté), 0032, 0050
module UseCases
  module Identity
    class ResetPinWithCode
      # Contact inconnu, code absent, révoqué ou faux : le même message.
      INVALID = { base: [ :invalid_recovery ] }.freeze

      def initialize(users:, pin_recoveries:, sessions:, login_attempts:, audit_log:, transaction:, digest_key:, clock:)
        @users = users
        @pin_recoveries = pin_recoveries
        @sessions = sessions
        @login_attempts = login_attempts
        @audit_log = audit_log
        @transaction = transaction
        @digest_key = digest_key
        @clock = clock
      end

      # dto : Dtos::Identity::PinResetInput. → success | :invalid | :expired
      def call(dto:)
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        now = @clock.now
        @transaction.call { reset(dto, now) }
      end

      private

      def reset(dto, now)
        user = @users.find_by_contact(contact: dto.contact)
        code = @pin_recoveries.active_for(user_id: user.id) unless user.nil?
        return Shared::Result.failure(:invalid, errors: INVALID) if code.nil?

        case code.status(now:)
        when :expired then Shared::Result.failure(:expired)
        when :revoked then Shared::Result.failure(:invalid, errors: INVALID)
        else check(user, code, dto, now)
        end
      end

      def check(user, code, dto, now)
        unless Entities::Identity::SecretDigest.secure_compare(code.code_digest, Entities::Identity::SecretDigest.hmac(dto.code, key: @digest_key))
          @pin_recoveries.record_failure(id: code.id, at: now)
          return Shared::Result.failure(:invalid, errors: INVALID)
        end

        apply(user, code, dto, now)
        Shared::Result.success
      end

      def apply(user, code, dto, now)
        @users.update_pin(user_id: user.id, pin: dto.pin)
        @pin_recoveries.consume(id: code.id, at: now)
        @sessions.destroy_all_for(user_id: user.id)
        @login_attempts.clear_failures(contact: dto.contact)
        @audit_log.record(action: "pin.reset", actor_id: user.id, subject_type: "User", subject_id: user.id, ip: dto.ip, at: now)
      end
    end
  end
end
