# 🌐 DELIVERY · Assessment::SessionResultsController
# Rôle : résultat d'une session terminée, pour l'élève propriétaire, l'enseignant d'une de ses classes actives et l'équipe
# ADR  : 0026, 0028, 0033, 0054 · UDR : 0007, 0023 · lecture seule, aucun stream
module Assessment
  class SessionResultsController < AuthenticatedController
    def show
      session = Repositories::Assessment::ExerciseSessionRepository.new.find_by_public_id(public_id: params[:public_id])
      return render_not_found if session.nil?

      render_result Policies::Assessment::ReadSessionPolicy.new.call(actor: current_actor, session:, teaches_student: teaches?(session)),
                    success: ->(_) { load_result(session) }
    end

    private

    # Session en cours : on la termine d'abord ; abandonnée, la page de la session mène à l'exercice.
    def load_result(session)
      return redirect_to exercise_session_path(session.public_id) unless session.completed?

      exercise = Repositories::Assessment::ExerciseRepository.new.find(id: session.exercise_id)
      # Décision du porteur (881a623) : l'élève ne reçoit jamais les propositions correctes, la query ne les lit pas.
      @reveal = Policies::Assessment::RevealAnswersPolicy.new.call(actor: current_actor, exercise:).success?
      @result = query.call(public_id: session.public_id, reveal: @reveal)
      @owner = session.student_id == current_actor.user_id
      @can_restart = Policies::Assessment::StartSessionPolicy.new.call(actor: current_actor, exercise:).success?
    end

    def teaches?(session)
      return false unless current_actor.teacher?

      query.teaches_student?(student_id: session.student_id, teacher_id: current_actor.user_id)
    end

    def query
      @query ||= Queries::Assessment::SessionResultQuery.new
    end
  end
end
