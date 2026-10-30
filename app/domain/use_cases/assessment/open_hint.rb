# 🧠 DOMAINE · UseCases::Assessment::OpenHint
# Rôle : l'élève ouvre l'indice d'une question de sa copie en cours ; l'ouverture est enregistrée (une fois), puis le texte est rendu
# ADR  : 0120-questions-a-plusieurs-cases-et-indice (§4) · UDR : 0146-je-m-entraine-dans-la-fiche (§3.8)
module UseCases
  module Assessment
    class OpenHint
      # hint : le texte de l'indice, rendu seulement ici, jamais dans la page de la copie.
      Opened = Data.define(:question_id, :hint)

      def initialize(sessions:, exercises:, policy:, transaction:)
        @sessions = sessions
        @exercises = exercises
        @policy = policy
        @transaction = transaction
      end

      # → Result(Opened) | :not_found : copie introuvable, d'un autre élève, rendue ou abandonnée, question hors de l'exercice ou sans
      # indice. Un seul code pour tous ces refus : rien ne dit à un tiers que la copie existe.
      def call(actor:, public_id:, question_id:)
        @transaction.call { locked(actor, public_id, question_id) }
      end

      private

      def locked(actor, public_id, question_id)
        session = @sessions.find_by_public_id(public_id:, lock: true)
        return not_found if session.nil? || @policy.call(actor:, session:).failure?

        question = @exercises.find(id: session.exercise_id)&.questions&.find { it.id == question_id }
        return not_found if question.nil? || question.hint.blank?

        @sessions.record_hint(session_id: session.id, question_id: question.id)
        Shared::Result.success(Opened.new(question_id: question.id, hint: question.hint))
      end

      def not_found = Shared::Result.failure(:not_found)
    end
  end
end
