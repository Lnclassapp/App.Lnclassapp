# 🧠 DOMAINE · Entities::Assessment::QuestionAttempt
# Rôle : tentative immuable d'une question dans une session ; response_text pour les trous et le nombre
# ADR  : 0054, 0091
module Entities
  module Assessment
    QuestionAttempt = Data.define(:session_id, :question_id, :selected_answer_ids, :correct, :answered_at, :response_text) do
      def initialize(response_text: nil, **) = super
    end
  end
end
