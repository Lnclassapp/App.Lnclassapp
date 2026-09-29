# 🧠 DOMAINE · UseCases::Identity::VerifyOwnPin
# Rôle : revérifie le PIN actuel de son propre compte ; l'échec compte et verrouille comme la connexion
# ADR  : 0028, 0050, 0055
module UseCases
  module Identity
    class VerifyOwnPin
      # Le compteur de la connexion : un PIN faux ici rapproche du même verrouillage (ADR-0055).
      KIND = Authenticate::KIND
      INVALID = { current_pin: [ :incorrect ] }.freeze

      def initialize(users:, login_attempts:, audit_log:, policy:, clock:)
        @users = users
        @login_attempts = login_attempts
        @audit_log = audit_log
        @policy = policy
        @clock = clock
      end

      # user : Entities::Identity::User, le compte de l'acteur. → success | :forbidden | :invalid | :locked (errors[:retry_after])
      def call(actor:, user:, pin:, ip:)
        allowed = @policy.call(actor:, target: user)
        return allowed if allowed.failure?

        now = @clock.now
        failures = @login_attempts.consecutive_failures(contact: user.contact, kind: KIND)
        locked = locked(failures.count, failures.last_failed_at, now)
        return locked if locked

        accepted = !@users.authenticate(contact: user.contact, pin:).nil?
        # Un succès remet le compteur à zéro, comme une connexion réussie.
        @login_attempts.record(contact: user.contact, user_id: user.id, ip:, succeeded: accepted, kind: KIND, at: now)
        return Shared::Result.success if accepted

        reject(user, failures.count + 1, ip, now)
      end

      private

      # Le verrouillage que la connexion suivante trouverait : le contrôleur ferme alors la session en cours.
      def reject(user, failures, ip, now)
        if Entities::Identity::Lockout.tier_reached?(failures)
          @audit_log.record(action: "login.locked", actor_id: nil, subject_type: "User", subject_id: user.id,
                            metadata: { kind: KIND, failures: }, ip:, at: now)
        end
        locked(failures, now, now) || Shared::Result.failure(:invalid, errors: INVALID)
      end

      def locked(failures, last_failed_at, now)
        retry_after = Entities::Identity::Lockout.retry_after(failures:, last_failed_at:, now:)
        Shared::Result.failure(:locked, errors: { retry_after: }) if retry_after
      end
    end
  end
end
