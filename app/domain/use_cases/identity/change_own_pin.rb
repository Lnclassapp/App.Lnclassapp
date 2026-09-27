# 🧠 DOMAINE · UseCases::Identity::ChangeOwnPin
# Rôle : change son propre PIN sous PIN actuel ; une nouvelle session remplace toutes les autres ; « pin.changed » sans donnée
# ADR  : 0025, 0028, 0050, 0055 · UDR : 0041
module UseCases
  module Identity
    class ChangeOwnPin
      # token : le jeton en clair de la nouvelle session, que le contrôleur pose dans le cookie (start_session).
      Changed = Data.define(:token)
      UNCHANGED = { pin: [ :unchanged ] }.freeze

      def initialize(users:, sessions:, login_attempts:, audit_log:, transaction:, policy:, digest_key:, clock:)
        @users = users
        @sessions = sessions
        @login_attempts = login_attempts
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @digest_key = digest_key
        @clock = clock
      end

      # user : Entities::Identity::User, le compte de l'acteur ; session : Entities::Identity::SessionState, celle en cours.
      # dto : Dtos::Identity::PinChangeInput. → success(Changed) | :forbidden | :invalid | :locked (errors[:retry_after])
      def call(actor:, user:, session:, dto:)
        allowed = @policy.call(actor:, target: user)
        return allowed if allowed.failure?
        # Une faute de saisie ne coûte pas un essai de PIN : le formulaire est vérifié d'abord.
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        verified = verify_pin.call(actor:, user:, pin: dto.current_pin, ip: dto.ip)
        return verified if verified.failure?
        # Dit seulement une fois le PIN actuel reconnu : avant, le message pourrait être faux.
        return Shared::Result.failure(:invalid, errors: UNCHANGED) if dto.pin == dto.current_pin

        @transaction.call { change(user, session, dto, @clock.now) }
      end

      private

      def verify_pin
        VerifyOwnPin.new(users: @users, login_attempts: @login_attempts, audit_log: @audit_log, policy: @policy, clock: @clock)
      end

      def change(user, session, dto, now)
        @users.update_pin(user_id: user.id, pin: dto.pin)
        token = renew(user, session, dto, now)
        @audit_log.record(action: "pin.changed", actor_id: user.id, subject_type: "User", subject_id: user.id, ip: dto.ip, at: now)
        Shared::Result.success(Changed.new(token:))
      end

      # Même renouvellement que ChangeOwnContact : une nouvelle session remplace toutes les autres, celle en cours comprise ;
      # le second facteur vérifié le reste.
      def renew(user, session, dto, now)
        token = Entities::Identity::SecretDigest.generate_token
        id = @sessions.create(user_id: user.id, token_digest: Entities::Identity::SecretDigest.hmac(token, key: @digest_key),
                              ip: dto.ip, user_agent: dto.user_agent, at: now)
        @sessions.mark_second_factor_verified(id:, at: now) if session.verified?
        @sessions.destroy_all_except(user_id: user.id, keep_id: id)
        token
      end
    end
  end
end
