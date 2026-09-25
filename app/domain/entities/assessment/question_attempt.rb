# 🧠 DOMAINE · Entities::Assessment::QuestionAttempt
# Rôle : tentative immuable d'une question dans une session
# ADR  : 0054
module Entities
  module Assessment
    QuestionAttempt = Data.define(:session_id, :question_id, :selected_answer_ids, :correct, :answered_at)
  end
end
