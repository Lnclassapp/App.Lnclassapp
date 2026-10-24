# 🧠 DOMAINE · UseCases::Classroom::ChangeClassroomLink
# Rôle : change ensemble le lien et le code d'une classe, sous son verrou ; l'ancien lien et l'ancien code sont invalides aussitôt, journalisé
# ADR  : 0026, 0028, 0085, XXXX-code-de-classe-a-six-caracteres (§4.3) · UDR : 0081 (§3.6)
module UseCases
  module Classroom
    class ChangeClassroomLink
      def initialize(classrooms:, audit_log:, policy:, transaction:, clock:)
        @classrooms = classrooms
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # policy : ManageClassroomMembersPolicy, interrogée sur la classe lue sous verrou.
      # → Result(Classroom, avec son nouveau link_token et son nouveau join_code) | :not_found | :forbidden (y compris base: classroom_archived)
      def call(actor:, public_id:)
        @transaction.call { change(actor, public_id) }
      end

      private

      # Le verrou est celui de l'adhésion : un élève qui entre par l'ancien lien ou l'ancien code passe avant ou est refusé, jamais entre deux.
      def change(actor, public_id)
        classroom = @classrooms.lock_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if classroom.nil?

        allowed = @policy.call(actor:, classroom:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:forbidden, errors: { base: [ :classroom_archived ] }) unless classroom.active?

        renewed = @classrooms.regenerate_link_and_code(id: classroom.id)
        classroom.link_token = renewed.link_token
        classroom.join_code = renewed.join_code
        record(actor, classroom)
        Shared::Result.success(classroom)
      end

      # Ni le jeton ni le code dans le journal : qui, quelle classe, quand.
      def record(actor, classroom)
        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "School",
                          subject_id: classroom.school_id,
                          metadata: { change: "classroom_link_and_code_changed", classroom_public_id: classroom.public_id })
      end
    end
  end
end
