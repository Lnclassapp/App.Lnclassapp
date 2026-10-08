# 🧠 DOMAINE · UseCases::Classroom::ChangeClassroomLink
# Rôle : tire un nouveau jeton du lien d'une classe, sous son verrou ; l'ancien lien est invalide aussitôt, un lien par classe
# ADR  : 0026, 0028, 0085 · UDR : 0081 (§3.6)
module UseCases
  module Classroom
    class ChangeClassroomLink
      def initialize(classrooms:, policy:, transaction:)
        @classrooms = classrooms
        @policy = policy
        @transaction = transaction
      end

      # policy : ManageClassroomMembersPolicy, interrogée sur la classe lue sous verrou.
      # → Result(Classroom, avec son nouveau link_token) | :not_found | :forbidden (y compris base: classroom_archived)
      def call(actor:, public_id:)
        @transaction.call { change(actor, public_id) }
      end

      private

      # Le verrou est celui de l'adhésion : un élève qui entre par l'ancien lien passe avant ou est refusé, jamais entre deux.
      def change(actor, public_id)
        classroom = @classrooms.lock_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if classroom.nil?

        allowed = @policy.call(actor:, classroom:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:forbidden, errors: { base: [ :classroom_archived ] }) unless classroom.active?

        classroom.link_token = @classrooms.rotate_link_token(id: classroom.id)
        Shared::Result.success(classroom)
      end
    end
  end
end
