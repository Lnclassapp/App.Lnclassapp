# 🔌 INFRA · Queries::Crm::BriefingInputsQuery
# Rôle : les faits d'une école pour la fiche de briefing (étape, usage, 5 derniers échanges, relances ouvertes, fonctions des contacts) ; notes masquées ; requêtes en nombre constant
# ADR  : XXXX (modèles de langage, « Données envoyées » : aucun nom d'élève, de contact ni numéro) · lecture seule (CQRS)
module Queries
  module Crm
    class BriefingInputsQuery
      EXCHANGES = 5
      FOLLOW_UPS = 5

      # Une école par public_id (le clic) ou par id (le job). → Entities::Crm::BriefingPrompt | nil
      def call(public_id: nil, school_id: nil, today: Date.current)
        school = Orm::School.includes(:drena).find_by(**{ public_id:, id: school_id }.compact)
        return nil if school.nil?

        usage = SchoolUsageQuery.new.call(school_ids: [ school.id ], today:).fetch(school.id)
        saved = Orm::CrmAccount.find_by(school_id: school.id)&.stage
        Entities::Crm::BriefingPrompt.new(
          school_id: school.id, school_name: school.name, drena_name: school.drena.name, stage: usage.stage(saved:, today:).to_s,
          accounts_count: usage.accounts_count, active_students_count: usage.active_students_count, last_activity_on: usage.last_activity_on,
          contact_positions: contact_positions(school.id), interactions: interactions(school.id), follow_ups: follow_ups(school.id)
        )
      end

      private

      def contact_positions(school_id) = Orm::CrmContact.where(school_id:, archived_at: nil).order(:id).pluck(:position)

      # Les champs libres partent masqués (numéros, noms des contacts, archivés compris) ; les noms d'élèves ne se filtrent pas.
      def interactions(school_id)
        names = Orm::CrmContact.where(school_id:).pluck(:full_name)
        Orm::CrmInteraction.where(school_id:).order(occurred_at: :desc, id: :desc).limit(EXCHANGES)
                           .pluck(:occurred_at, :kind, :outcome, :next_step, :note)
                           .map do |at, kind, outcome, next_step, note|
          { occurred_on: at.in_time_zone.to_date, kind:, outcome:,
            next_step: Entities::Crm::Redaction.call(next_step, names:), note: Entities::Crm::Redaction.call(note, names:) }
        end
      end

      def follow_ups(school_id)
        names = Orm::CrmContact.where(school_id:).pluck(:full_name)
        Orm::CrmFollowUp.open.where(school_id:).order(:due_on, :id).limit(FOLLOW_UPS).pluck(:due_on, :reason)
                        .map { |due_on, reason| { due_on:, reason: Entities::Crm::Redaction.call(reason, names:) } }
      end
    end
  end
end
