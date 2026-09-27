# 🧠 DOMAINE · Policies::Classroom::TeachPolicy
# Rôle : autorise l'enseignant de la classe et l'équipe à agir sur une classe
# ADR  : 0028, 0030
module Policies
  module Classroom
    class TeachPolicy
      def call(actor:, classroom:)
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success if actor.team?
        return Shared::Result.success if actor.teacher? && classroom.teacher_ids.include?(actor.user_id)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
