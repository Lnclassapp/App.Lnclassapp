# 🌐 DELIVERY · Assessment::ExerciseSessionsController
# Rôle : l'élève démarre (exercice de son niveau), reprend ou recommence un exercice, puis remplit sa copie ; terminée → résultat
# ADR  : 0026, 0028, 0043, 0048, 0054, 0112, 0115 · UDR : 0022, 0138 §3.2
module Assessment
  class ExerciseSessionsController < AuthenticatedController
    include ReadsOwnLevel

    allow_roles :student

    # « Commencer », « Reprendre » ou « Recommencer » (restart=true) : change de page, sans stream.
    def create
      return if refuse_out_of_level(exercise_public_id: params[:exercise_public_id])

      result = start_session.call(actor: current_actor, exercise_public_id: params[:exercise_public_id],
                                  restart: params[:restart] == "true")
      return redirect_paused(result.errors.fetch(:resume_at)) if result.code == :conflict

      render_result result, success: ->(session) { redirect_to exercise_session_path(session.public_id), status: :see_other }
    end

    def show
      @play = Queries::Assessment::SessionPlayQuery.new.copy(public_id: params[:public_id])
      return render_not_found if @play.nil?
      return render_forbidden if Policies::Assessment::ReadSessionPolicy.new.call(actor: current_actor, session: @play).failure?
      # Une session ouverte avant la règle de niveau (UDR-0013, 2026-10-01) ne se joue plus hors niveau.
      return if refuse_out_of_level(exercise_public_id: @play.exercise_public_id)
      return redirect_to exercise_session_result_path(@play.session_public_id) if @play.completed?

      # Une session abandonnée par « Recommencer » ne se remplit plus : retour à l'exercice.
      redirect_to exercise_path(@play.exercise_public_id), alert: t(".abandoned") unless @play.started?
    end

    private

    # ADR-0115 : pause de « Recommencer » ; retour à l'exercice, qui dit l'heure de reprise.
    def redirect_paused(resume_at)
      redirect_to exercise_path(params[:exercise_public_id]), status: :see_other,
                  alert: t("assessment.exercises.show.paused", time: l(resume_at, format: :hour_minute))
    end

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
