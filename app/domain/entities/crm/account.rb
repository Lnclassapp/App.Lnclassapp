# 🧠 DOMAINE · Entities::Crm::Account
# Rôle : suivi d'une école : étape saisie, responsable, motif de perte ; son absence vaut « Prospect » sans responsable
# ADR  : XXXX (contexte crm)
module Entities
  module Crm
    Account = Data.define(:school_id, :stage, :owner_id, :lost_reason, :stage_changed_at) do
      def self.blank(school_id) = new(school_id:, stage: "prospect", owner_id: nil, lost_reason: nil, stage_changed_at: nil)

      def owned? = !owner_id.nil?
    end
    Account::LOST_REASONS = %w[price equipment network calendar competitor no_interest other].freeze
  end
end
