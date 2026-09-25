# 🧠 DOMAINE · Policies::Assessment::SubmitAttemptPolicy
# Rôle : seul l'élève propriétaire répond, et seulement dans une session ouverte
# ADR  : 0028, 0054
module Policies
  module Assessment
    class SubmitAttemptPolicy
      # session : Entities::Assessment::ExerciseSession
      def call(actor:, session:)
        return Shared::Result.failure(:forbidden) unless actor&.student? && session.student_id == actor.user_id
        return Shared::Result.failure(:forbidden, errors: { base: [ :session_closed ] }) unless session.started?

        Shared::Result.success
      end
    end
  end
end
