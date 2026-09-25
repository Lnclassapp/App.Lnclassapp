# 🧠 DOMAINE · Policies::Assessment::ReadSessionPolicy
# Rôle : lire une session : l'élève propriétaire, l'enseignant d'une classe active de l'élève, l'équipe
# ADR  : 0028, 0043
module Policies
  module Assessment
    class ReadSessionPolicy
      # teaches_student : l'élève est dans une classe active que l'enseignant enseigne
      def call(actor:, session:, teaches_student: false)
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success if actor.team?
        return Shared::Result.success if actor.student? && session.student_id == actor.user_id
        return Shared::Result.success if actor.teacher? && teaches_student

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
