# 🌐 DELIVERY · Assessment::SessionResultsController
# Rôle : résultat d'une session terminée, pour l'élève propriétaire, l'enseignant d'une de ses classes actives et l'équipe
# ADR  : 0026, 0028, 0033, 0054, 0094, 0115 · UDR : 0007, 0023, 0140 · lecture seule, aucun stream
module Assessment
  class SessionResultsController < AuthenticatedController
    include ReadsOwnLevel

    def show
      session = Repositories::Assessment::ExerciseSessionRepository.new.find_by_public_id(public_id: params[:public_id])
      return render_not_found if session.nil?

      render_result Policies::Assessment::ReadSessionPolicy.new.call(actor: current_actor, session:, teaches_student: teaches?(session)),
                    success: ->(_) { load_result(session) }
    end

    private

    # Session en cours : on la termine d'abord ; abandonnée, la page de la session mène à l'exercice.
    def load_result(session)
      # Après ReadSessionPolicy : l'élève ne relit pas son résultat d'un exercice hors de son niveau (UDR-0013, 2026-10-01) ;
      # l'enseignant et l'équipe, si.
      return if refuse_out_of_level(exercise_id: session.exercise_id)

      return redirect_to exercise_session_path(session.public_id) unless session.completed?

      exercise = Repositories::Assessment::ExerciseRepository.new.find(id: session.exercise_id)
      # ADR-0115 (amende la décision du porteur 881a623) : l'élève lit la correction de sa copie vérifiée, jamais avant ;
      # sans accord de la policy, la query ne lit ni bonnes réponses ni corrigés types.
      @reveal = Policies::Assessment::RevealCorrectionPolicy.new.call(actor: current_actor, exercise:, session:).success?
      @result = query.call(public_id: session.public_id, reveal: @reveal)
      @owner = session.student_id == current_actor.user_id
      @resume_at = restart_resume_at(session) if @owner
      @can_restart = @resume_at.nil? && Policies::Assessment::StartSessionPolicy.new.call(actor: current_actor, exercise:).success?
    end

    # L'heure de reprise si l'élève est en pause sur cet exercice (RestartPause), nil sinon. Le refus d'une nouvelle copie
    # est celui de StartExerciseSession ; ici, on ne fait que le dire.
    def restart_resume_at(session)
      completions = Repositories::Assessment::ExerciseSessionRepository.new
                                                                       .recent_completions(student_id: session.student_id, exercise_id: session.exercise_id)
      Entities::Assessment::RestartPause.resume_at(completions:, now: Time.current)
    end

    def teaches?(session)
      return false unless current_actor.teacher?

      query.teaches_student?(student_id: session.student_id, teacher_id: current_actor.user_id, school_id: current_actor.school_id)
    end

    def query
      @query ||= Queries::Assessment::SessionResultQuery.new
    end
  end
end
