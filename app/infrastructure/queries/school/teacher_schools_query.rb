# 🔌 INFRA · Queries::School::TeacherSchoolsQuery
# Rôle : les établissements d'un enseignant (principal d'abord, puis par date de rattachement), pour le panneau du compte et « Mes établissements »
# ADR  : 0006, 0094 · UDR : 0098, 0099
module Queries
  module School
    class TeacherSchoolsQuery
      # current : l'établissement courant de la session (actor.school_id). Aucun identifiant de la base (ADR-0029).
      Row = Data.define(:public_id, :name, :sigle, :drena_name, :primary, :current)

      COLUMNS = [ "schools.id", "schools.public_id", "schools.name", "schools.sigle", "drenas.name", "teacher_schools.primary" ].freeze

      # teacher_id, current_school_id : du compte connecté, jamais un paramètre. → [Row], une requête
      def call(teacher_id:, current_school_id:)
        Orm::TeacherSchool.joins(school: :drena).where(teacher_id:)
                          .order("teacher_schools.primary DESC, teacher_schools.created_at, teacher_schools.id")
                          .pluck(*COLUMNS.map { Arel.sql(it) })
                          .map do |id, public_id, name, sigle, drena_name, primary|
                            Row.new(public_id:, name:, sigle:, drena_name:, primary:, current: id == current_school_id)
                          end
      end
    end
  end
end
