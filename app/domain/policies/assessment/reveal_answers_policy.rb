# 🧠 DOMAINE · Policies::Assessment::RevealAnswersPolicy
# Rôle : montrer les bonnes réponses : équipe et enseignant toujours ; l'élève seulement pour une question déjà tentée
# ADR  : 0028, 0054
module Policies
  module Assessment
    class RevealAnswersPolicy
      # L'enseignant voit la correction de tout exercice (porteur, 2026-09-25), contrairement à l'ADR-0028.
      # attempted_question_ids : questions tentées dans la session de l'élève
      def call(actor:, question_id: nil, attempted_question_ids: [])
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success if actor.team? || actor.teacher?
        return Shared::Result.success if actor.student? && attempted_question_ids.include?(question_id)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
