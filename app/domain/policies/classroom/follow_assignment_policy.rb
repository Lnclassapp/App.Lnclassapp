# 🧠 DOMAINE · Policies::Classroom::FollowAssignmentPolicy
# Rôle : suivre un exercice assigné (comptes et retardataires nommés) : l'enseignant de la classe et l'équipe seulement
# ADR  : 0028, 0072
module Policies
  module Classroom
    class FollowAssignmentPolicy
      # classroom : répond à teacher_ids ; active ou archivée. La direction ne voit ni les retards ni les noms (ADR-0072 §4.5).
      def call(actor:, classroom:)
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success if actor.team?
        return Shared::Result.success if actor.teacher? && classroom.teacher_ids.include?(actor.user_id)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
