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

      # Garde les `limit` abonnements les plus récemment enregistrés de l'élève, supprime les autres. → nombre supprimé
      def delete_oldest_beyond(user_id:, limit:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete_oldest_beyond"
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

      # Les abonnements rattachés à la session `from_session_id` passent à `to_session_id`. → nombre rattaché
      def reattach_session(from_session_id:, to_session_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #reattach_session"
      end

      # Tous les abonnements de l'élève sauf ceux de la session `session_id`, session_id NULL compris. → nombre supprimé
      def delete_for_user_except_session(user_id:, session_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete_for_user_except_session"
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

      # Remet le compteur d'échecs à zéro (l'envoi abandonné ne compte plus pour le motif suivant).
      def reset_failures(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #reset_failures"
      end

      # Sans envoi réussi depuis `before` (ni enregistré depuis : `updated_at`, remis à jour par `register`). → nombre supprimé
      def delete_stale(before:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete_stale"
      end
    end
  end
end
