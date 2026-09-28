# 🧠 DOMAINE · UseCases::Identity::ChangeOwnContact
# Rôle : change son propre numéro sous PIN actuel ; ferme les autres sessions et renouvelle la sienne
# ADR  : 0028, 0050, 0055 · UDR : 0041
module UseCases
  module Identity
    class ChangeOwnContact
      include SessionRenewal

      # token : le jeton en clair de la nouvelle session, que le contrôleur pose dans le cookie (start_session).
      Changed = Data.define(:token)
      UNCHANGED = { contact: [ :unchanged ] }.freeze

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
      # dto : Dtos::Identity::ContactChangeInput. → success(Changed) | :forbidden | :invalid | :locked | :conflict
      def call(actor:, user:, session:, dto:)
        allowed = @policy.call(actor:, target: user)
        return allowed if allowed.failure?
        # Une faute de saisie ne coûte pas un essai de PIN : le formulaire est vérifié d'abord.
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?
        return Shared::Result.failure(:invalid, errors: UNCHANGED) if dto.contact == user.contact

        verified = verify_pin.call(actor:, user:, pin: dto.current_pin, ip: dto.ip)
        return verified if verified.failure?

        @transaction.call { change(user, session, dto, @clock.now) }
      end

      private

      def verify_pin
        VerifyOwnPin.new(users: @users, login_attempts: @login_attempts, audit_log: @audit_log, policy: @policy, clock: @clock)
      end

      # Un numéro pris rend :conflict sans rien écrire ; le message affiché reste neutre (ADR-0055).
      def change(user, session, dto, now)
        changed = @users.update_contact(user_id: user.id, contact: dto.contact)
        return changed if changed.failure?

        token = renew(user, session, dto, now)
        @audit_log.record(action: "contact.changed", actor_id: user.id, subject_type: "User", subject_id: user.id,
                          metadata: { from: mask(user.contact), to: mask(dto.contact) }, ip: dto.ip, at: now)
        Shared::Result.success(Changed.new(token:))
      end

      # Seuls les deux derniers chiffres restent lisibles dans le journal.
      def mask(contact) = contact.gsub(/\d(?=\d{2})/, "*")
    end
  end
end
