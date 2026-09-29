# 🔌 INFRA · Queries::Classroom::ClassroomHeaderQuery
# Rôle : en-tête d'une classe et faits de ReadClassroomPolicy et d'AssignPolicy (enseignants, élèves actifs)
# ADR  : 0026, 0028, 0041 · UDR : 0054 (school_public_id : retour de l'équipe vers la fiche de l'établissement)
module Queries
  module Classroom
    class ClassroomHeaderQuery
      Row = Data.define(:public_id, :name, :level_name, :series_name, :school_name, :school_public_id, :school_year,
                        :status, :join_code_display, :max_students, :active_students_count, :teacher_ids, :student_ids)

      COLUMNS = [ "classrooms.id", "classrooms.public_id", "classrooms.name", "levels.name", "series.name", "schools.name",
                  "schools.public_id", "classrooms.school_year", "classrooms.status", "classrooms.join_code", "classrooms.max_students" ].freeze

      def call(public_id:)
        id, public_id, name, level_name, series_name, school_name, school_public_id, school_year, status, join_code, max_students =
          Orm::Classroom.joins(:level, :school).left_joins(:series).where(public_id:).pick(*COLUMNS)
        return if id.nil?

        student_ids = Orm::ClassroomStudent.where(classroom_id: id, left_at: nil).order(:student_id).pluck(:student_id)
        Row.new(public_id:, name:, level_name:, series_name:, school_name:, school_public_id:, school_year:, status:,
                join_code_display: Entities::Classroom::JoinCode.display(join_code), max_students:,
                active_students_count: student_ids.size, student_ids:,
                teacher_ids: Orm::TeacherClassroom.where(classroom_id: id).order(:teacher_id).pluck(:teacher_id))
      end
    end
  end
end
