# 🧠 DOMAINE · Entities::Assessment::QuestionAttempt
# Rôle : tentative immuable d'une question dans une session ; response_text pour les trous et le nombre
# ADR  : 0054, 0091, 0120-questions-a-plusieurs-cases-et-indice (§4 : blank_responses, blank_results)
module Entities
  module Assessment
    # blank_responses : la réponse de chaque case ([String]) ; blank_results : son verdict ([Boolean]) ; vides pour une question à une case.
    QuestionAttempt = Data.define(:session_id, :question_id, :selected_answer_ids, :correct, :answered_at, :response_text,
                                  :blank_responses, :blank_results) do
      def initialize(response_text: nil, blank_responses: [], blank_results: [], **) = super
    end
  end
end
