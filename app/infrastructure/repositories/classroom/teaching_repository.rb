# 🔌 INFRA · Repositories::Classroom::TeachingRepository
# Rôle : déclarations d'enseignement (teacher_classrooms), idempotentes ; les retirer efface d'abord les jours de séance liés
# ADR  : 0030, 0071, 0072
module Repositories
  module Classroom
    class TeachingRepository
      include Ports::Classroom::TeachingRepositoryPort

      def declare(teacher_id:, classroom_id:, at:)
        inserted = Orm::TeacherClassroom.insert({ teacher_id:, classroom_id:, created_at: at },
                                                unique_by: %i[teacher_id classroom_id])
        inserted.length.zero? ? :already : :created
      end

      # ADR-0072 §4.2 : la clé composite (RESTRICT) des jours de séance refuserait le retrait ; ils partent d'abord.
      def withdraw(teacher_id:, classroom_id:)
        Orm::TeacherClassroom.transaction do
          Orm::ClassroomSessionDay.where(teacher_id:, classroom_id:).delete_all
          Orm::TeacherClassroom.where(teacher_id:, classroom_id:).delete_all
        end
        true
      end

      def classroom_ids_for(teacher_id:)
        Orm::TeacherClassroom.where(teacher_id:).order(:classroom_id).pluck(:classroom_id)
      end

      # Deux DELETE bornés aux classes de l'établissement (sous-requête), toutes années confondues : les jours de séance,
      # puis les déclarations (ADR-0071 §4.5, ADR-0072 §4.2).
      def withdraw_all_in_school(teacher_id:, school_id:)
        classroom_id = Orm::Classroom.where(school_id:).select(:id)
        Orm::TeacherClassroom.transaction do
          Orm::ClassroomSessionDay.where(teacher_id:, classroom_id:).delete_all
          Orm::TeacherClassroom.where(teacher_id:, classroom_id:).delete_all
        end
      end
    end
  end
end
