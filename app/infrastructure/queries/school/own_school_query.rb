# 🔌 INFRA · Queries::School::OwnSchoolQuery
# Rôle : l'établissement de la direction pour sa page « Établissement » : nom, type, statut et code, quel que soit le statut
# ADR  : 0006, 0057, 0071 · UDR : 0056
module Queries
  module School
    class OwnSchoolQuery
      COLUMNS = %i[public_id name school_type status school_code].freeze

      Row = Data.define(*COLUMNS) do
        # Un établissement inactif ou en brouillon se lit, sans geste (UDR-0056 §2.6).
        def active? = status == "active"
      end

      # school_id : current_actor.school_id, jamais un paramètre. → Row | nil
      def call(school_id:)
        return if school_id.nil?

        values = Orm::School.where(id: school_id).pick(*COLUMNS)
        values && Row.new(*values)
      end
    end
  end
end
