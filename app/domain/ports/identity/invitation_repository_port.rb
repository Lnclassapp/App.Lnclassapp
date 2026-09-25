# 🧠 DOMAINE · Ports::Identity::InvitationRepositoryPort
# Rôle : contrat des invitations, une seule en attente par type et par contact
# ADR  : 0038, 0044
module Ports
  module Identity
    module InvitationRepositoryPort
      # → Result(Entities::Identity::Invitation) | failure(:conflict, errors: { contact: [:already_invited] })
      def create(kind:, contact:, team_role:, invited_by_id:, token_digest:, expires_at:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # → Entities::Identity::Invitation | nil
      def find_by_token_digest(token_digest:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_token_digest"
      end

      # → true
      def mark_accepted(id:, user_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #mark_accepted"
      end
    end
  end
end
