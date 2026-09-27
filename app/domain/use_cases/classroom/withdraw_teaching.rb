# 🧠 DOMAINE · UseCases::Classroom::WithdrawTeaching
# Rôle : un enseignant se retire d'une classe ; ses assignations et les sessions des élèves restent
# ADR  : 0026, 0028, 0030 · UDR : 0025
module UseCases
  module Classroom
    class WithdrawTeaching
      def initialize(classrooms:, teachings:, policy:)
        @classrooms = classrooms
        @teachings = teachings
        @policy = policy
      end

      # → Result(Entities::Classroom::Classroom) | :not_found | :forbidden (autre école, classe archivée)
      def call(actor:, classroom_public_id:)
        classroom = @classrooms.find_by_public_id(public_id: classroom_public_id)
        return Shared::Result.failure(:not_found) if classroom.nil?

        allowed = @policy.call(actor:, classroom:)
        return allowed if allowed.failure?

        @teachings.withdraw(teacher_id: actor.user_id, classroom_id: classroom.id)
        Shared::Result.success(classroom)
      end
    end
  end
end
