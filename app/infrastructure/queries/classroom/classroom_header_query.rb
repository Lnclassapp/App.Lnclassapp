# 🔌 INFRA · Queries::Classroom::ClassroomHeaderQuery
# Rôle : en-tête d'une classe, jeton de son lien et faits de ReadClassroomPolicy, d'AssignPolicy et de ManageClassroomMembersPolicy
# ADR  : 0026, 0028, 0041, 0085 · UDR : 0054 (school_public_id : retour de l'équipe vers la fiche), 0081 (§3.6 : bloc du lien)
module Queries
  module Classroom
    class ClassroomHeaderQuery
      MANAGE_POLICY = Policies::Classroom::ManageClassroomMembersPolicy.new

      Row = Data.define(:public_id, :name, :level_name, :series_name, :school_id, :school_name, :school_public_id, :school_year,
                        :status, :link_token, :max_students, :active_students_count, :teacher_ids,
                        :student_ids) do
        # UDR-0081 §3.6 : le bloc du lien, pour qui gère la classe, et seulement sur une classe active.
        def link_shown_to?(actor) = status == "active" && MANAGE_POLICY.call(actor:, classroom: self).success?
      end

      COLUMNS = [ "classrooms.id", "classrooms.public_id", "classrooms.name", "levels.name", "series.name", "schools.id",
                  "schools.name", "schools.public_id", "classrooms.school_year", "classrooms.status", "classrooms.link_token",
                  "classrooms.max_students" ].freeze

      def call(public_id:)
        id, public_id, name, level_name, series_name, school_id, school_name, school_public_id, school_year, status, link_token,
          max_students = Orm::Classroom.joins(:level, :school).left_joins(:series).where(public_id:).pick(*COLUMNS)
        return if id.nil?

        student_ids = Orm::ClassroomStudent.where(classroom_id: id, left_at: nil).order(:student_id).pluck(:student_id)
        Row.new(public_id:, name:, level_name:, series_name:, school_id:, school_name:, school_public_id:, school_year:, status:,
                link_token:, max_students:,
                active_students_count: student_ids.size, student_ids:,
                teacher_ids: Orm::TeacherClassroom.where(classroom_id: id).order(:teacher_id).pluck(:teacher_id))
      end
    end
  end
end
