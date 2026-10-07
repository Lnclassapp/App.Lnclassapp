# 🔌 INFRA · Queries::School::SchoolPreviewQuery
# Rôle : bandeau d'un lien d'invitation : nom de l'établissement et de sa DRENA, rien d'autre ; établissement actif seulement
# ADR  : 0082 · UDR : 0078
module Queries
  module School
    class SchoolPreviewQuery
      Row = Data.define(:school_name, :drena_name)

      ACTIVE = "active".freeze

      # → Row | nil (inconnu, inactif ou en brouillon : aucune différence)
      def call(school_id:)
        school_name, drena_name = Orm::School.joins(:drena).where(id: school_id, status: ACTIVE).pick("schools.name", "drenas.name")
        Row.new(school_name:, drena_name:) if school_name
      end
    end
  end
end
