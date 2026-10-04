# 🧠 DOMAINE · Ports::Communication::DismissalRepositoryPort
# Rôle : contrat des rejets d'annonces : un élève masque une annonce sur tous ses appareils, puis l'annule
# ADR  : 0045, 0078
module Ports
  module Communication
    # Propre au Lot B (un seul consommateur) ; un rejet est unique par annonce et par compte.
    module DismissalRepositoryPort
      # Idempotent : un second rejet garde la date du premier. → true
      def dismiss(message_id:, user_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #dismiss"
      end

      # → true si un rejet a été effacé, false s'il n'y en avait pas
      def restore(message_id:, user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #restore"
      end
    end
  end
end
