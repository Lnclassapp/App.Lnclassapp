# 🔌 INFRA · Queries::Classroom::JoinPreviewQuery
# Rôle : aperçu public d'une classe par son code : nom de la classe, de l'établissement et du niveau, rien d'autre
# ADR  : 0041 · UDR : 0009
module Queries
  module Classroom
    class JoinPreviewQuery
      Row = Data.define(:classroom_name, :school_name, :level_name)

      COLUMNS = [ "classrooms.name", "schools.name", "levels.name" ].freeze

      # → Row | nil (code inconnu, remplacé ou fermé)
      def call(code:)
        join_code = Entities::Classroom::JoinCode.normalize(code)
        return if join_code.empty?

        classroom_name, school_name, level_name = Orm::Classroom.joins(:school, :level).where(join_code:).pick(*COLUMNS)
        Row.new(classroom_name:, school_name:, level_name:) if classroom_name
      end
    end
  end
end
