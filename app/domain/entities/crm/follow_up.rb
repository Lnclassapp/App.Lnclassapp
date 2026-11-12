# 🧠 DOMAINE · Entities::Crm::FollowUp
# Rôle : relance d'une école, confiée à un membre, ouverte puis faite ; terminer une relance faite est sans effet
# ADR  : XXXX (contexte crm)
module Entities
  module Crm
    FollowUp = Data.define(:public_id, :school_id, :assignee_id, :due_on, :reason, :status, :done_at, :done_by_id, :created_by_id,
                           :interaction_id) do
      def open? = status == "open"
      def due?(today) = open? && due_on <= today
    end
    FollowUp::STATUSES = %w[open done].freeze
    FollowUp::REASON_MAX = 200
  end
end
