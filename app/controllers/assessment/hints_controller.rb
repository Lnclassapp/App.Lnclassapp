# 🌐 DELIVERY · Assessment::HintsController
# Rôle : l'élève ouvre l'indice d'une question de sa copie en cours ; Turbo Stream (replace hint_<id>), sans JavaScript retour à la copie
# ADR  : 0120-questions-a-plusieurs-cases-et-indice §4 · UDR : 0147-je-m-entraine-dans-la-fiche §3.8 · sécurité : question_id lu en entier, jamais d'indice avant l'enregistrement
module Assessment
  class HintsController < AuthenticatedController
    allow_roles :student

    def create
      question_id = params[:question_id].to_s.to_i
      result = open_hint.call(actor: current_actor, public_id: params[:public_id], question_id:)

      render_result result, success: lambda { |opened|
        @opened = opened
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to exercise_session_path(params[:public_id], anchor: anchor_for(opened.question_id)), status: :see_other }
        end
      }
    end

    private

    # L'ancre de la question dans la copie ; rien si son rang ne se lit pas (la copie vient d'être rendue ailleurs).
    def anchor_for(question_id)
      number = number_of(question_id)
      "question-#{number}" if number
    end

    # Rang de la question dans son exercice, lu sur la copie de l'élève.
    def number_of(question_id)
      copy = Queries::Assessment::SessionPlayQuery.new.copy(public_id: params[:public_id])
      copy.questions.find { it.id == question_id }&.number if copy
    end

    def open_hint
      UseCases::Assessment::OpenHint.new(
        sessions: Repositories::Assessment::ExerciseSessionRepository.new, exercises: Repositories::Assessment::ExerciseRepository.new,
        policy: Policies::Assessment::SubmitAttemptPolicy.new, transaction: Repositories::Shared::Transaction.new
      )
    end
  end
end
