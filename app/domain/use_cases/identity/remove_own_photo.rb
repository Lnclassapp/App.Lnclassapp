# 🧠 DOMAINE · UseCases::Identity::RemoveOwnPhoto
# Rôle : chacun retire sa photo de profil ; le fichier est effacé et le retrait tracé ; sans photo, rien ne se passe
# ADR  : 0026, 0028, 0060
module UseCases
  module Identity
    class RemoveOwnPhoto
      def initialize(photos:, audit_log:, transaction:, policy:, clock:)
        @photos = photos
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # user : Entities::Identity::User, le compte de l'acteur. → success(true si une photo a été retirée) | :forbidden
      def call(actor:, user:, ip:)
        allowed = @policy.call(actor:, target: user)
        return allowed if allowed.failure?
        return Shared::Result.success(false) unless @photos.attached?(user_id: user.id)

        @transaction.call { remove(user, ip) }
      end

      private

      # La trace s'écrit avant l'effacement : si l'effacement échoue, la transaction annule la trace, jamais l'inverse.
      def remove(user, ip)
        @audit_log.record(action: "profile.photo_removed", actor_id: user.id, at: @clock.now, subject_type: "User",
                          subject_id: user.id, ip:)
        Shared::Result.success(@photos.remove(user_id: user.id))
      end
    end
  end
end
