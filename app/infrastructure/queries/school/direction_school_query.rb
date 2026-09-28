# 🔌 INFRA · Queries::School::DirectionSchoolQuery
# Rôle : en-tête de l'établissement de la direction (nom, DRENA, type, statut, code d'établissement affiché) ; lui seul
# ADR  : 0057, 0066 · UDR : 0052
module Queries
  module School
    class DirectionSchoolQuery
      Row = Data.define(:public_id, :name, :drena_name, :school_type, :status, :school_code) do
        # « k7m4qz » → « K7M-4QZ » (ADR-0057).
        def school_code_display = Entities::School::SchoolCode.display(school_code)
      end

      COLUMNS = %w[schools.public_id schools.name drenas.name schools.school_type schools.status schools.school_code].freeze

      # school_id : toujours current_actor.school_id, jamais un paramètre (ADR-0066 §4.4). → Row | nil
      def call(school_id:)
        values = Orm::School.joins(:drena).where(id: school_id).pick(*COLUMNS)
        values && Row.new(*values)
      end
    end
  end
end
