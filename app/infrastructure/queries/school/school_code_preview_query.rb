# 🔌 INFRA · Queries::School::SchoolCodePreviewQuery
# Rôle : aperçu public d'un établissement par son code : nom de l'établissement et de sa DRENA, rien d'autre ; actif seulement
# ADR  : 0057 · UDR : 0044
module Queries
  module School
    class SchoolCodePreviewQuery
      Row = Data.define(:school_name, :drena_name)

      ACTIVE = "active".freeze

      # → Row | nil (code inconnu, remplacé, ou établissement inactif ou en brouillon : aucune différence)
      def call(code:)
        school_code = Entities::School::SchoolCode.normalize(code)
        return unless Entities::School::SchoolCode.valid?(school_code)

        school_name, drena_name = Orm::School.joins(:drena).where(school_code:, status: ACTIVE).pick("schools.name", "drenas.name")
        Row.new(school_name:, drena_name:) if school_name
      end
    end
  end
end
