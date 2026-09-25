# 🧠 DOMAINE · UseCases::Classroom::ArchiveAssignment
# Rôle : l'enseignant de la classe, ou l'équipe, retire une ressource : la ligne est archivée, jamais supprimée
# ADR  : 0026, 0028, 0036, 0048
module UseCases
  module Classroom
    class ArchiveAssignment
      Archived = Data.define(:assignment, :classroom)

      def initialize(classrooms:, assignments:, policy:, clock:)
        @classrooms = classrooms
        @assignments = assignments
        @policy = policy
        @clock = clock
      end

      # La classe est annoncée par l'écran : l'assignation doit lui appartenir.
      # → Result(Archived) | :not_found | :forbidden | :conflict (base: already_archived)
      def call(actor:, classroom_public_id:, public_id:)
        classroom = @classrooms.find_by_public_id(public_id: classroom_public_id)
        return Shared::Result.failure(:not_found) if classroom.nil?

        allowed = @policy.call(actor:, classroom:)
        return allowed if allowed.failure?

        assignment = @assignments.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if assignment.nil? || assignment.classroom_id != classroom.id
        return Shared::Result.failure(:conflict, errors: { base: [ :already_archived ] }) unless assignment.active?

        at = @clock.now
        @assignments.archive(id: assignment.id, archived_by_id: actor.user_id, at:)
        Shared::Result.success(Archived.new(assignment: assignment.with(status: "archived", archived_at: at), classroom:))
      end
    end
  end
end
