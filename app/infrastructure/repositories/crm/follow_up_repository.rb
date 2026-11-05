# 🔌 INFRA · Repositories::Crm::FollowUpRepository
# Rôle : écrit et relit les relances (table crm_follow_ups) ; terminer une relance faite est sans effet ; partagé par les Lots C et D
# ADR  : XXXX (contexte crm)
module Repositories
  module Crm
    class FollowUpRepository
      include Ports::Crm::FollowUpRepositoryPort

      # Un identifiant public inconnu (ou d'une autre école) est refusé : jamais un lien nul en silence.
      def create(follow_up:, interaction_public_id: nil)
        interaction_id = follow_up.interaction_id
        if interaction_public_id
          interaction_id = Orm::CrmInteraction.where(school_id: follow_up.school_id).find_by(public_id: interaction_public_id)&.id
          return ::Shared::Result.failure(:not_found) if interaction_id.nil?
        end

        record = Orm::CrmFollowUp.create!(school_id: follow_up.school_id, assignee_id: follow_up.assignee_id, due_on: follow_up.due_on,
                                          reason: follow_up.reason, status: follow_up.status, done_at: follow_up.done_at,
                                          done_by_id: follow_up.done_by_id, created_by_id: follow_up.created_by_id,
                                          interaction_id:)
        ::Shared::Result.success(to_entity(record))
      end

      def find_by_public_id(public_id:)
        record = Orm::CrmFollowUp.find_by(public_id:)
        to_entity(record) if record
      end

      # Sous verrou : deux « Faite » simultanés laissent le premier auteur et la première date.
      def complete(public_id:, by_id:, at:)
        record = Orm::CrmFollowUp.find_by(public_id:)
        return ::Shared::Result.failure(:not_found) if record.nil?

        record.with_lock { record.update!(status: "done", done_at: at, done_by_id: by_id) if record.status == "open" }
        ::Shared::Result.success(to_entity(record))
      end

      def reassign(public_id:, assignee_id:)
        record = Orm::CrmFollowUp.find_by(public_id:)
        return ::Shared::Result.failure(:not_found) if record.nil?

        record.update!(assignee_id:)
        ::Shared::Result.success(to_entity(record))
      end

      private

      def to_entity(record)
        Entities::Crm::FollowUp.new(public_id: record.public_id, school_id: record.school_id, assignee_id: record.assignee_id,
                                    due_on: record.due_on, reason: record.reason, status: record.status, done_at: record.done_at,
                                    done_by_id: record.done_by_id, created_by_id: record.created_by_id,
                                    interaction_id: record.interaction_id)
      end
    end
  end
end
