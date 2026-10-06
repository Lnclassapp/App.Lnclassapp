# 🧠 DOMAINE · Ports::Identity::InvitationRepositoryPort
# Rôle : contrat des invitations, une seule en attente par type et par contact
# ADR  : 0036 (§4), 0038, 0044
module Ports
  module Identity
    module InvitationRepositoryPort
      # team : team_role requis ; school_staff : school_id et position requis (ADR-0044).
      # → Result(Entities::Identity::Invitation) | failure(:conflict, errors: { contact: [:already_invited] })
      def create(kind:, contact:, team_role:, invited_by_id:, token_digest:, expires_at:, school_id: nil, position: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # → Entities::Identity::Invitation | nil
      def find_by_token_digest(token_digest:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_token_digest"
      end

      # Révoque les invitations en attente expirées de ce contact, pour qu'il puisse être réinvité. → Integer
      def revoke_expired(kind:, contact:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #revoke_expired"
      end

      # ADR-0036 §4 : à la suppression d'un compte, ses invitations partent avec lui : celle qu'il a acceptée et toute invitation
      # adressée à son numéro. Celles qu'il a envoyées à d'autres numéros restent. → Integer (nombre supprimé)
      def destroy_all_for(user_id:, contact:)
        raise NotImplementedError, "#{self.class} doit implémenter #destroy_all_for"
      end

      # → true
      def mark_accepted(id:, user_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #mark_accepted"
      end
    end
  end
end
