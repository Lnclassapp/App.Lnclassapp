# 🔌 INFRA · Queries::Classroom::JoinPreviewQuery
# Rôle : aperçu public d'une classe par le jeton de son lien : nom de la classe, de l'établissement et du niveau, et « complète »
# ADR  : 0041, 0085 · UDR : 0081
module Queries
  module Classroom
    class JoinPreviewQuery
      # full : la page du lien le dit au lieu d'offrir le formulaire.
      LinkRow = Data.define(:classroom_name, :school_name, :level_name, :full)

      COLUMNS = [ "classrooms.name", "schools.name", "levels.name" ].freeze
      LINK_COLUMNS = [ *COLUMNS, "classrooms.id", "classrooms.max_students" ].freeze

      # ADR-0085 §4.1 : le lien n'est valable que pour une classe active d'un établissement actif.
      # → LinkRow | nil (jeton inconnu ou changé, classe archivée, établissement en brouillon ou désactivé)
      def link(token:)
        values = token.presence && Orm::Classroom.joins(:school, :level)
                                                 .where(link_token: token, status: "active", schools: { status: "active" })
                                                 .pick(*LINK_COLUMNS)
        return unless values

        classroom_name, school_name, level_name, id, max_students = values
        full = Orm::ClassroomStudent.where(classroom_id: id, left_at: nil).count >= max_students
        LinkRow.new(classroom_name:, school_name:, level_name:, full:)
      end
    end
  end
end
