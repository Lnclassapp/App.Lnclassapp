# 🔌 INFRA · Repositories::Crm::InteractionRepository
# Rôle : écrit et relit le journal des échanges d'une école (table crm_interactions) ; ajout seul, ni mise à jour ni suppression
# ADR  : XXXX (contexte crm)
module Repositories
  module Crm
    class InteractionRepository
      include Ports::Crm::InteractionRepositoryPort

      # Du plus récent au plus ancien ; l'identifiant départage deux échanges de même instant.
      def recent_for_school(school_id:, limit:, offset:)
        Orm::CrmInteraction.where(school_id:).order(occurred_at: :desc, id: :desc).limit(limit).offset(offset).map { to_entity(it) }
      end

      def create(interaction:)
        record = Orm::CrmInteraction.create!(
          school_id: interaction.school_id, author_id: interaction.author_id, kind: interaction.kind,
          occurred_at: interaction.occurred_at, contact_id: interaction.contact_id, contact_name: interaction.contact_name,
          outcome: interaction.outcome, next_step: interaction.next_step, note: interaction.note, source: interaction.source
        )
        ::Shared::Result.success(to_entity(record))
      end

      private

      def to_entity(record)
        Entities::Crm::Interaction.new(public_id: record.public_id, school_id: record.school_id, author_id: record.author_id,
                                       kind: record.kind, occurred_at: record.occurred_at, contact_id: record.contact_id,
                                       contact_name: record.contact_name, outcome: record.outcome, next_step: record.next_step,
                                       note: record.note, source: record.source)
      end
    end
  end
end
