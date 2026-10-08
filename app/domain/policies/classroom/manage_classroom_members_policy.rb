# 🧠 DOMAINE · Policies::Classroom::ManageClassroomMembersPolicy
# Rôle : lien d'une classe et retrait d'un élève : l'enseignant de la classe, la direction de son établissement, l'équipe
# ADR  : 0028, 0085
module Policies
  module Classroom
    class ManageClassroomMembersPolicy
      # Hors de son périmètre, la classe n'existe pas pour un enseignant ni pour une direction : :not_found, pas :forbidden.
      def call(actor:, classroom:)
        return Shared::Result.failure(:forbidden) if actor.nil? || actor.student?
        return Shared::Result.success if actor.team?
        return Shared::Result.success if actor.teacher? && classroom.teacher_ids.include?(actor.user_id)
        return Shared::Result.success if actor.school_admin? && actor.school_id && actor.school_id == classroom.school_id

        Shared::Result.failure(:not_found)
      end
    end
  end
end
