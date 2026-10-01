# 🌐 DELIVERY · Assessment::QuestionAttemptsController
# Rôle : l'élève répond à une question de son niveau ; verdict et progression en Turbo Stream, erreur de saisie en 422
# ADR  : 0026, 0028, 0054 · UDR : 0006, 0007, 0022
module Assessment
  class QuestionAttemptsController < AuthenticatedController
    include ReadsOwnLevel

    allow_roles :student

    # Sa propre session hors niveau (ouverte avant la règle de l'UDR-0013, 2026-10-01) ne reçoit plus de réponse : 404. La
    # session d'un autre élève reste refusée par le use case (403), sans rien dire de son niveau.
    def create
      return if own_session? && refuse_out_of_level(session_public_id: params[:public_id])

      @form = Dtos::Assessment::AttemptInput.new(session_public_id: params[:public_id],
                                                 **params.expect(attempt: [ :question_id, { answer_ids: [] } ]).to_h.symbolize_keys)
      result = submit_attempt.call(actor: current_actor, dto: @form)
      return refuse_answer(result) if result.code == :invalid
      return answer_again(result) if result.code == :conflict

      render_result result, success: ->(submitted) { render_verdict(submitted) }
    end

    private

    def own_session?
      Repositories::Assessment::ExerciseSessionRepository.new.find_by_public_id(public_id: params[:public_id])&.student_id ==
        current_actor.user_id
    end

    def render_verdict(submitted)
      @play = play(feedback_question_id: submitted.question_id)
      respond_to do |format|
        format.turbo_stream
        format.html do
          redirect_to exercise_session_path(@play.session_public_id), status: :see_other,
                                                                      notice: t(".#{submitted.correct ? :success : :error}")
        end
      end
    end

    # La carte de la question se rouvre avec son erreur, dans le frame « question », sans rechargement de page.
    def refuse_answer(result)
      add_errors(result)
      @play = play
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("question", partial: "assessment/exercise_sessions/question_card",
                                                                locals: { play: @play, question: @play.next_question, form: @form }),
                 status: :unprocessable_entity
        end
        format.html { render "assessment/exercise_sessions/show", status: :unprocessable_entity }
      end
    end

    # Déjà répondue, ou session close : rien n'est écrit, retour à l'état réel de la session (ADR-0054).
    def answer_again(result)
      message = t("activemodel.errors.models.dtos/assessment/attempt_input.attributes.base.#{result.errors.fetch(:base).first}")
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [ helpers.turbo_stream_toast(message, type: :warning), turbo_stream.refresh(request_id: nil) ]
        end
        format.html { redirect_to exercise_session_path(params[:public_id]), alert: message, status: :see_other }
      end
    end

    def play(**options) = Queries::Assessment::SessionPlayQuery.new.call(public_id: params[:public_id], **options)

    def submit_attempt
      sessions = Repositories::Assessment::ExerciseSessionRepository.new
      transaction = Repositories::Shared::Transaction.new
      UseCases::Assessment::SubmitQuestionAttempt.new(
        sessions:, exercises: Repositories::Assessment::ExerciseRepository.new, policy: Policies::Assessment::SubmitAttemptPolicy.new,
        close: UseCases::Assessment::CloseExerciseSession.new(
          sessions:, badges: Repositories::Assessment::BadgeRepository.new, gaps: Repositories::Assessment::KnowledgeGapRepository.new,
          policy: Policies::Assessment::SubmitAttemptPolicy.new, transaction:, clock: Time.zone
        ),
        transaction:, clock: Time.zone
      )
    end
  end
end
