# 🧠 DOMAINE · Policies::Assessment::RevealAnswersPolicy
# Rôle : montrer les bonnes réponses : l'élève pour une question déjà tentée, l'équipe ; jamais l'enseignant
# ADR  : 0028, 0054
module Policies
  module Assessment
    class RevealAnswersPolicy
      # attempted_question_ids : questions tentées dans la session de l'élève
      def call(actor:, question_id: nil, attempted_question_ids: [])
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success if actor.team?
        return Shared::Result.success if actor.student? && attempted_question_ids.include?(question_id)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
