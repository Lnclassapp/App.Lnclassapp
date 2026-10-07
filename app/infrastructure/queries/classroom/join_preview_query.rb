# 🔌 INFRA · Queries::Classroom::JoinPreviewQuery
# Rôle : aperçu public d'une classe par son code ou par le jeton de son lien : nom de la classe, de l'établissement et du niveau
# ADR  : 0041, 0083 · UDR : 0009, 0079
module Queries
  module Classroom
    class JoinPreviewQuery
      Row = Data.define(:classroom_name, :school_name, :level_name)
      # full : la page du lien le dit au lieu d'offrir le formulaire. join_code : pont vers JoinAsStudent, qui ne connaît
      # encore que le code (jusqu'au Lot B) ; jamais rendu.
      LinkRow = Data.define(:classroom_name, :school_name, :level_name, :full, :join_code)

      COLUMNS = [ "classrooms.name", "schools.name", "levels.name" ].freeze
      LINK_COLUMNS = [ *COLUMNS, "classrooms.id", "classrooms.max_students", "classrooms.join_code" ].freeze

      # → Row | nil (code inconnu, remplacé ou fermé)
      def call(code:)
        join_code = Entities::Classroom::JoinCode.normalize(code)
        return if join_code.empty?

        classroom_name, school_name, level_name = Orm::Classroom.joins(:school, :level).where(join_code:).pick(*COLUMNS)
        Row.new(classroom_name:, school_name:, level_name:) if classroom_name
      end

      # ADR-0083 §4.1 : le lien n'est valable que pour une classe active d'un établissement actif.
      # → LinkRow | nil (jeton inconnu ou changé, classe archivée, établissement en brouillon ou désactivé)
      def link(token:)
        values = token.presence && Orm::Classroom.joins(:school, :level)
                                                 .where(link_token: token, status: "active", schools: { status: "active" })
                                                 .pick(*LINK_COLUMNS)
        return unless values

        classroom_name, school_name, level_name, id, max_students, join_code = values
        full = Orm::ClassroomStudent.where(classroom_id: id, left_at: nil).count >= max_students
        LinkRow.new(classroom_name:, school_name:, level_name:, full:, join_code:)
      end
    end
  end
end
