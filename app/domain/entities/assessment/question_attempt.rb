# 🧠 DOMAINE · Entities::Assessment::QuestionAttempt
# Rôle : tentative immuable d'une question dans une session ; response_text pour les trous et le nombre
# ADR  : 0054, 0091, 0120-questions-a-plusieurs-cases-et-indice (§4 : blank_responses, blank_results), médailles-lues-a-la-cloture (unanswered)
module Entities
  module Assessment
    # unanswered : la question est restée vide à la copie (ne compte pas comme une réponse donnée).
    # blank_responses : la réponse de chaque case ([String]) ; blank_results : son verdict ([Boolean]) ; vides pour une question à une case.
    QuestionAttempt = Data.define(:session_id, :question_id, :selected_answer_ids, :correct, :answered_at, :response_text,
                                  :blank_responses, :blank_results, :unanswered) do
      def initialize(response_text: nil, blank_responses: [], blank_results: [], unanswered: false, **) = super
    end
  end
end
