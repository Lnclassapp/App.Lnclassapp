# 🧠 DOMAINE · UseCases::Classroom::DeclareTeaching
# Rôle : un enseignant se déclare dans une classe active de son école principale ; idempotent
# ADR  : 0026, 0028, 0030 · UDR : 0025
module UseCases
  module Classroom
    class DeclareTeaching
      def initialize(classrooms:, teachings:, policy:, clock:)
        @classrooms = classrooms
        @teachings = teachings
        @policy = policy
        @clock = clock
      end

      # → Result(Entities::Classroom::Classroom) | :not_found | :forbidden (autre école, classe archivée)
      def call(actor:, classroom_public_id:)
        classroom = @classrooms.find_by_public_id(public_id: classroom_public_id)
        return Shared::Result.failure(:not_found) if classroom.nil?

        allowed = @policy.call(actor:, classroom:)
        return allowed if allowed.failure?

        @teachings.declare(teacher_id: actor.user_id, classroom_id: classroom.id, at: @clock.now)
        Shared::Result.success(classroom)
      end
    end
  end
end
