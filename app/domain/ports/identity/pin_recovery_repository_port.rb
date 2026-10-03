# 🧠 DOMAINE · Ports::Identity::PinRecoveryRepositoryPort
# Rôle : contrat des codes de récupération du PIN, un seul actif par compte
# ADR  : 0032, 0036
module Ports
  module Identity
    module PinRecoveryRepositoryPort
      # Révoque le code actif précédent. → true
      def issue(user_id:, issued_by_id:, code_digest:, expires_at:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #issue"
      end

      # Ni utilisé ni révoqué. → Entities::Identity::PinRecoveryCode | nil
      def active_for(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #active_for"
      end

      # → Integer (nouveau compteur) ; révoque à PinRecoveryCode::MAX_FAILED_ATTEMPTS
      def record_failure(id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record_failure"
      end

      # Pose used_at. → true
      def consume(id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #consume"
      end

      # Supprime tous les codes du compte, actifs ou non (anonymisation, ADR-0036 §4). → Integer (codes supprimés)
      def destroy_all_for(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #destroy_all_for"
      end
    end
  end
end
