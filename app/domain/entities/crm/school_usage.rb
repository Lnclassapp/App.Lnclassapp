# 🧠 DOMAINE · Entities::Crm::SchoolUsage
# Rôle : usage réel d'une école (comptes rattachés, élèves actifs sur 14 jours, dernière activité, premier rattachement)
# ADR  : XXXX (contexte crm)
module Entities
  module Crm
    SchoolUsage = Data.define(:school_id, :accounts_count, :active_students_count, :last_activity_on, :first_attached_on) do
      def self.none(school_id) = new(school_id:, accounts_count: 0, active_students_count: 0, last_activity_on: nil, first_attached_on: nil)

      def stage(saved:, today:)
        Stage.resolve(saved:, accounts_count:, last_activity_on:, today:)
      end
    end
  end
end
