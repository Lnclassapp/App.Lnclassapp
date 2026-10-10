# 🔌 INFRA · Queries::Classroom::JoinPreviewQuery
# Rôle : aperçu public d'une classe par le jeton de son lien : nom de la classe, de l'établissement et du niveau, « complète » et « archivée »
# ADR  : 0041, 0085, 0088 · UDR : 0081
module Queries
  module Classroom
    class JoinPreviewQuery
      # full : la page du lien le dit au lieu d'offrir le formulaire ; archived : le bandeau le dit (ADR-0088), et l'entrée
      # est refusée par JoinPolicy.
      LinkRow = Data.define(:classroom_name, :school_name, :level_name, :full, :archived)

      COLUMNS = [ "classrooms.name", "schools.name", "levels.name" ].freeze
      LINK_COLUMNS = [ *COLUMNS, "classrooms.id", "classrooms.max_students", "classrooms.status" ].freeze

      # ADR-0085 §4.1 : le lien n'est valable que pour une classe d'un établissement actif. ADR-0088 : une classe archivée
      # garde son lien (le jeton ne change pas) mais refuse l'entrée, et la page le dit.
      # → LinkRow | nil (jeton inconnu ou changé, établissement en brouillon ou désactivé)
      def link(token:)
        values = token.presence && Orm::Classroom.joins(:school, :level)
                                                 .where(link_token: token, schools: { status: "active" })
                                                 .pick(*LINK_COLUMNS)
        return unless values

        classroom_name, school_name, level_name, id, max_students, status = values
        full = Orm::ClassroomStudent.where(classroom_id: id, left_at: nil).count >= max_students
        LinkRow.new(classroom_name:, school_name:, level_name:, full:, archived: status == "archived")
      end
    end
  end
end
