# 🧠 DOMAINE · Ports::Communication::PushDeliveryRepositoryPort
# Rôle : contrat des envois : anti-doublon par clé d'objet, dernier envoi (intervalle), purge à 90 jours
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.2)
module Ports
  module Communication
    module PushDeliveryRepositoryPort
      # Un envoi est unique par élève, motif et clé d'objet. → true si enregistré, false si déjà connu
      def record(user_id:, motive:, object_key:, status:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record"
      end

      def sent?(user_id:, motive:, object_key:)
        raise NotImplementedError, "#{self.class} doit implémenter #sent?"
      end

      # → Time | nil : le dernier envoi réellement parti (statut `delivered`)
      def last_sent_at(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #last_sent_at"
      end

      # → nombre supprimé
      def purge_before(time)
        raise NotImplementedError, "#{self.class} doit implémenter #purge_before"
      end
    end
  end
end
