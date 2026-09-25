# 🔌 INFRA · Repositories::Identity::InvitationRepository
# Rôle : invitations (empreinte du jeton seulement), une seule en attente par type et par contact
# ADR  : 0038, 0044
module Repositories
  module Identity
    class InvitationRepository
      include Ports::Identity::InvitationRepositoryPort

      # Point de sauvegarde : l'index unique refusé n'invalide pas la transaction du use case.
      def create(kind:, contact:, team_role:, invited_by_id:, token_digest:, expires_at:)
        record = Orm::Invitation.transaction(requires_new: true) do
          Orm::Invitation.create!(kind:, contact:, team_role:, invited_by_id:, token_digest:, expires_at:)
        end
        ::Shared::Result.success(map(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { contact: [ :already_invited ] })
      end

      def find_by_token_digest(token_digest:)
        record = Orm::Invitation.find_by(token_digest:)
        map(record) unless record.nil?
      end

      def mark_accepted(id:, user_id:, at:)
        Orm::Invitation.where(id:).update_all(accepted_at: at, accepted_user_id: user_id, updated_at: at)
        true
      end

      private

      def map(record)
        Entities::Identity::Invitation.new(
          id: record.id, kind: record.kind, contact: record.contact, team_role: record.team_role, school_id: record.school_id,
          invited_by_id: record.invited_by_id, expires_at: record.expires_at, accepted_at: record.accepted_at,
          accepted_user_id: record.accepted_user_id, revoked_at: record.revoked_at
        )
      end
    end
  end
end
