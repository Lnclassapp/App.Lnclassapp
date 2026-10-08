# 🧠 DOMAINE · UseCases::Classroom::RemoveStudent
# Rôle : l'enseignant de la classe, la direction de son établissement ou l'équipe retire un élève ; compte, sessions et résultats restent
# ADR  : 0028, 0036, 0083 (§4.5) · UDR : 0079 (§3.7)
module UseCases
  module Classroom
    class RemoveStudent
      # removed : false quand l'élève était déjà retiré (retrait simultané, second envoi) : rien n'a été écrit.
      Removal = Data.define(:classroom, :student, :removed)

      def initialize(classrooms:, memberships:, users:, policy:, transaction:, clock:)
        @classrooms = classrooms
        @memberships = memberships
        @users = users
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # → success(Removal) | :forbidden (élève, visiteur ; classe archivée, base: classroom_archived) | :not_found (classe
      #   inconnue ou hors du périmètre de l'acteur ; compte inconnu, qui n'est pas un élève, ou ni dans la classe ni retiré d'elle)
      def call(actor:, classroom_public_id:, student_public_id:)
        @transaction.call { remove(actor, classroom_public_id, student_public_id) }
      end

      private

      # Sous le verrou de la classe : deux retraits simultanés passent l'un après l'autre, le second trouve l'élève parti.
      def remove(actor, classroom_public_id, student_public_id)
        classroom = @classrooms.lock_by_public_id(public_id: classroom_public_id)
        return Shared::Result.failure(:not_found) if classroom.nil?

        allowed = @policy.call(actor:, classroom:)
        return allowed if allowed.failure?
        # UDR-0079 §3.7, amendée le 2026-10-08 (porteur) : comme ChangeClassroomLink, rien ne bouge dans une classe archivée.
        return Shared::Result.failure(:forbidden, errors: { base: [ :classroom_archived ] }) unless classroom.active?

        student = @users.find_by_public_id(public_id: student_public_id)
        return Shared::Result.failure(:not_found) unless student&.student?

        removed = @memberships.remove(classroom_id: classroom.id, student_id: student.id, removed_by_id: actor.user_id,
                                      at: @clock.now)
        # Ni dans la classe ni retiré d'elle : l'élève n'existe pas pour qui gère la classe, et son nom ne sort pas.
        return Shared::Result.failure(:not_found) unless removed || @memberships.removed_from?(classroom_id: classroom.id,
                                                                                               student_id: student.id)

        Shared::Result.success(Removal.new(classroom:, student:, removed:))
      end
    end
  end
end
