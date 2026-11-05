# 🌐 DELIVERY · Assessment::SessionResultsController
# Rôle : résultat d'une session terminée, pour l'élève propriétaire, l'enseignant d'une de ses classes actives et l'équipe
# ADR  : 0026, 0028, 0033, 0054, 0094, 0115, 0121 §4 · UDR : 0007, 0023, 0140, 0149 §3 · lecture seule, aucun stream ; return_to : retour vers la feuille ou « Ma classe »
module Assessment
  class SessionResultsController < AuthenticatedController
    include ReadsOwnLevel

    # Où ramène « Retour » quand l'élève vient de la feuille de la leçon ou de « Ma classe » : deux cibles, jamais une adresse libre.
    RETURN_TARGETS = %w[sheet class].freeze
    # L'ancre de la feuille d'où vient l'élève (sujet-avant-de-commencer) : jamais autre chose que ces caractères.
    SHEET_ANCHOR = /\A[a-z0-9_-]{1,255}\z/

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
      @return_to = params[:return_to] if @owner && RETURN_TARGETS.include?(params[:return_to])
      @sheet = params[:sheet] if RETURN_TARGETS.include?(@return_to) && params[:sheet].is_a?(String) && params[:sheet].match?(SHEET_ANCHOR)
      load_sheet(session) if @sheet
      load_remediation_proposal if @owner
      @resume_at = restart_resume_at(session) if @owner
      @can_restart = @resume_at.nil? && Policies::Assessment::StartSessionPolicy.new.call(actor: current_actor, exercise:).success?
    end

    # refaire-ou-continuer (UDR §3) : la feuille de l'élève d'où il vient, pour y ramener « Refaire » et « Continuer » ; `@sheet_found` faux
    # (feuille retirée, devoir d'une autre classe) : les boutons d'avant. Une erreur de lecture n'est pas avalée.
    def load_sheet(session)
      sheet = if @return_to == "sheet"
        Queries::Catalog::PrepareSheetsQuery.new.call(course_slug: @result.course_slug, actor: current_actor).sheet(@sheet)
      else
        Queries::Classroom::StudentAssignedSheetsQuery.new.sheet(actor: current_actor, dom_id: @sheet)
      end
      # Une feuille ne compte que si elle contient l'exercice de la copie (l'ancre d'une autre feuille : repli d'avant).
      @sheet_found = !sheet.nil? && sheet.exercises.any? { |entry| entry.public_id == @result.exercise.public_id }
      @next_exercise = (sheet.next_open(after: @result.exercise.public_id)&.public_id if @sheet_found)
    end

    # suivi-classe-lecon §3.3 : la copie qui a ouvert ou laissé en attente une lacune propose l'exercice de la fiche (@remediation_proposal) ;
    # une lacune levée ou une copie sans fiche n'en propose pas.
    def load_remediation_proposal
      return unless @result.essential && %i[opened still_pending].include?(@result.gap_outcome)

      @remediation_proposal = Queries::Assessment::RemediationProposalsQuery.new
                                                                            .call(student_id: current_actor.user_id, essential_slugs: [ @result.essential.slug ])[@result.essential.slug]
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
