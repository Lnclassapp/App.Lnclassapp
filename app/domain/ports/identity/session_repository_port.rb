# 🧠 DOMAINE · Ports::Identity::SessionRepositoryPort
# Rôle : contrat des sessions serveur, adressées par l'empreinte de leur jeton
# ADR  : 0031, 0050, 0055
module Ports
  module Identity
    module SessionRepositoryPort
      # → Integer (id)
      def create(user_id:, token_digest:, ip:, user_agent:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # → Entities::Identity::SessionState | nil ; role en chaîne (users.role)
      def find_by_token_digest(token_digest:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_token_digest"
      end

      # → true ; pose last_seen_at
      def touch(id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #touch"
      end

      # → true
      def mark_second_factor_verified(id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #mark_second_factor_verified"
      end

      # → true
      def destroy(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #destroy"
      end

      # → Integer (sessions supprimées)
      def destroy_all_for(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #destroy_all_for"
      end

      # → Integer (sessions supprimées) ; toutes celles du compte sauf keep_id, la session en cours
      def destroy_all_except(user_id:, keep_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #destroy_all_except"
      end
    end
  end
end
