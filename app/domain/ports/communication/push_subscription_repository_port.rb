# 🧠 DOMAINE · Ports::Communication::PushSubscriptionRepositoryPort
# Rôle : contrat des abonnements Web Push : enregistrer, lire, supprimer, noter un envoi
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.2)
module Ports
  module Communication
    module PushSubscriptionRepositoryPort
      # Une adresse déjà connue change de propriétaire (dernier compte connecté). → Entities::Communication::PushSubscription
      def register(user_id:, session_id:, endpoint:, p256dh:, auth:)
        raise NotImplementedError, "#{self.class} doit implémenter #register"
      end

      # → [PushSubscription]
      def for_user(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #for_user"
      end

      # Idempotent. → nombre de lignes supprimées
      def delete(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete"
      end

      def delete_for_user(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete_for_user"
      end

      def delete_for_sessions(session_ids:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete_for_sessions"
      end

      def record_success(id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record_success"
      end

      # → le nouveau nombre d'échecs
      def record_failure(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #record_failure"
      end

      # Sans envoi réussi depuis `before` (ni créé depuis). → nombre supprimé
      def delete_stale(before:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete_stale"
      end
    end
  end
end
