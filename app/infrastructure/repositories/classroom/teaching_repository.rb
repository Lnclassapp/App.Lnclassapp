# 🔌 INFRA · Repositories::Classroom::TeachingRepository
# Rôle : déclarations d'enseignement (teacher_classrooms), idempotentes ; les retirer ne touche à rien d'autre
# ADR  : 0030, 0071
module Repositories
  module Classroom
    class TeachingRepository
      include Ports::Classroom::TeachingRepositoryPort

      def declare(teacher_id:, classroom_id:, at:)
        inserted = Orm::TeacherClassroom.insert({ teacher_id:, classroom_id:, created_at: at },
                                                unique_by: %i[teacher_id classroom_id])
        inserted.length.zero? ? :already : :created
      end

      def withdraw(teacher_id:, classroom_id:)
        Orm::TeacherClassroom.where(teacher_id:, classroom_id:).delete_all
        true
      end

      def classroom_ids_for(teacher_id:)
        Orm::TeacherClassroom.where(teacher_id:).order(:classroom_id).pluck(:classroom_id)
      end

      # Un seul DELETE, borné aux classes de l'établissement (sous-requête), toutes années confondues.
      def withdraw_all_in_school(teacher_id:, school_id:)
        Orm::TeacherClassroom.where(teacher_id:, classroom_id: Orm::Classroom.where(school_id:).select(:id)).delete_all
      end
    end
  end
end
