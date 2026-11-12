# 🔌 INFRA · Queries::Crm::WhatsappDraftInputsQuery
# Rôle : les faits d'une relance pour le brouillon WhatsApp (école, motif, échéance, 3 derniers échanges) ; requêtes en nombre constant
# ADR  : XXXX (modèles de langage, « Données envoyées » : aucun nom d'élève ni de contact, aucun numéro) · lecture seule (CQRS)
module Queries
  module Crm
    class WhatsappDraftInputsQuery
      EXCHANGES = 3

      # Une relance ouverte par public_id (le clic) ; par id (le job), même faite depuis. → Entities::Crm::WhatsappDraftPrompt | nil
      def call(public_id: nil, id: nil)
        follow_up = public_id ? Orm::CrmFollowUp.open.find_by(public_id:) : Orm::CrmFollowUp.find_by(id:)
        return nil if follow_up.nil?

        school = Orm::School.includes(:drena).find(follow_up.school_id)
        Entities::Crm::WhatsappDraftPrompt.new(
          school_id: school.id, follow_up_id: follow_up.id, follow_up_public_id: follow_up.public_id, school_name: school.name,
          drena_name: school.drena.name, reason: Entities::Crm::Redaction.call(follow_up.reason, names: contact_names(school.id)), due_on: follow_up.due_on, interactions: interactions(school.id)
        )
      end

      # → String | nil : l'identifiant public d'une relance, pour « Réessayer » (la génération ne garde que l'id)
      def public_id_of(id:) = id && Orm::CrmFollowUp.where(id:).pick(:public_id)

      private

      # Contacts archivés compris : un nom retiré de la liste reste un nom de personne.
      def contact_names(school_id) = Orm::CrmContact.where(school_id:).pluck(:full_name)

      def interactions(school_id)
        names = contact_names(school_id)
        Orm::CrmInteraction.where(school_id:).order(occurred_at: :desc, id: :desc).limit(EXCHANGES)
                           .pluck(:occurred_at, :kind, :outcome, :next_step, :note)
                           .map do |at, kind, outcome, next_step, note|
          { occurred_on: at.in_time_zone.to_date, kind:, outcome:,
            next_step: Entities::Crm::Redaction.call(next_step, names:), note: Entities::Crm::Redaction.call(note, names:) }
        end
      end
    end
  end
end
