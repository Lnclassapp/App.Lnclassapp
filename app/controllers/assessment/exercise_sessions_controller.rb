# 🌐 DELIVERY · Assessment::ExerciseSessionsController
# Rôle : l'élève démarre, reprend ou recommence un exercice, puis joue sa session ; une session terminée mène au résultat
# ADR  : 0026, 0028, 0043, 0048, 0054 · UDR : 0022
module Assessment
  class ExerciseSessionsController < AuthenticatedController
    allow_roles :student

    # « Commencer », « Reprendre » ou « Recommencer » (restart=true) : change de page, sans stream.
    def create
      result = start_session.call(actor: current_actor, exercise_public_id: params[:exercise_public_id],
                                  restart: params[:restart] == "true")
      render_result result, success: ->(session) { redirect_to exercise_session_path(session.public_id), status: :see_other }
    end

    def show
      @play = Queries::Assessment::SessionPlayQuery.new.call(public_id: params[:public_id])
      return render_not_found if @play.nil?
      return render_forbidden if Policies::Assessment::ReadSessionPolicy.new.call(actor: current_actor, session: @play).failure?
      return redirect_to exercise_session_result_path(@play.session_public_id) if @play.completed?

      # Une session abandonnée par « Recommencer » ne se joue plus : retour à l'exercice.
      redirect_to exercise_path(@play.exercise_public_id), alert: t(".abandoned") unless @play.status == "started"
    end

    private

    def start_session
      UseCases::Assessment::StartExerciseSession.new(
        exercises: Repositories::Assessment::ExerciseRepository.new, sessions: Repositories::Assessment::ExerciseSessionRepository.new,
        gaps: Repositories::Assessment::KnowledgeGapRepository.new, memberships: Repositories::Classroom::MembershipRepository.new,
        assignments: Repositories::Classroom::AssignmentRepository.new, policy: Policies::Assessment::StartSessionPolicy.new,
        transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end
