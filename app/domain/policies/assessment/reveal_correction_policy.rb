# 🧠 DOMAINE · Policies::Assessment::RevealCorrectionPolicy
# Rôle : montrer la correction d'un résultat : équipe et enseignant comme RevealAnswersPolicy, élève seulement auteur d'une copie vérifiée
# ADR  : 0115 (§4 : amende la décision du 2026-09-25) · La feuille garde RevealAnswersPolicy : l'élève n'y voit jamais une bonne réponse
module Policies
  module Assessment
    class RevealCorrectionPolicy
      # exercise répond à id et readable_chain_published? ; session à exercise_id, student_id et completed?.
      # S'applique après ReadSessionPolicy (qui vérifie que l'enseignant enseigne à l'auteur) ; refuse toute copie d'un autre exercice.
      # Une copie en cours ou abandonnée n'a pas de correction, et un autre élève ne lit jamais celle d'autrui.
      def call(actor:, exercise:, session:)
        return Shared::Result.failure(:forbidden) unless session.exercise_id == exercise.id
        return student_result(actor, session) if actor&.student?

        RevealAnswersPolicy.new.call(actor:, exercise:)
      end

      private

      def student_result(actor, session)
        return Shared::Result.success if session.student_id == actor.user_id && session.completed?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
