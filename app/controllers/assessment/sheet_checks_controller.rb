# 🌐 DELIVERY · Assessment::SheetChecksController
# Rôle : « Vérifier ma réponse » sur la feuille de la leçon : une copie rendue, puis la page de résultat de la copie (return_to : le retour vers la feuille ou « Ma classe ») ; refus dans l'exercice en Turbo Stream, réponses gardées ; sans JS, retour à la leçon
# ADR  : 0121 (§4), 0054, 0091 (§4.4), 0115 · UDR : 0148 §3 · sécurité : copy[answers][<id>] lu champ par champ
module Assessment
  class SheetChecksController < AuthenticatedController
    include ReadsOwnLevel

    allow_roles :student

    def create
      return if refuse_out_of_level(exercise_public_id:)

      result = check_exercise.call(actor: current_actor, exercise_public_id:, answers: posted_answers, assignment_public_id:)
      return render_forbidden if result.code == :forbidden

      result.success? ? show_result(result.value) : refused(error_code(result), result.errors[:resume_at])
    rescue ActiveRecord::ActiveRecordError => error
      # Une panne n'est jamais avalée : elle est signalée, et l'élève relit « Réessaie » avec ses réponses.
      Rails.error.report(error, handled: true, severity: :error, source: "sheet_check",
                                context: { user_id: current_actor.user_id, exercise_public_id:, assignment_public_id: })
      refused(:failed)
    end

    private

    def exercise_public_id = params[:exercise_public_id]

    # « Rendre à l'enseignant » (Ma classe) poste le devoir ; seule une chaîne est lue, le use case vérifie qu'il est à l'élève.
    def assignment_public_id = (params[:assignment_public_id] if params[:assignment_public_id].is_a?(String) && params[:assignment_public_id].present?)

    # Ce que l'élève a posté, champ par champ : ni plus de trois champs par question, ni autre clé que celles que le DTO lit.
    def posted_answers
      copy = params[:copy]
      answers = copy[:answers] if copy.is_a?(ActionController::Parameters)
      return {} unless answers.is_a?(ActionController::Parameters)

      answers.to_unsafe_h.transform_values do |fields|
        fields.is_a?(Hash) ? fields.slice(*Dtos::Assessment::CopyInput::FIELDS.map(&:to_s)) : {}
      end
    end

    # La note de la copie est celle de la page de résultat (sur 20) ; le formulaire vise toute la page (data-turbo-frame="_top").
    def show_result(submitted)
      redirect_to exercise_session_result_path(submitted.session_public_id, return_to:), status: :see_other
    end

    # Deux retours seulement, jamais une adresse : l'exercice de la feuille, ou « Ma classe » (un devoir rendu, ou une feuille de « Ma classe »).
    def return_to = (assignment_public_id || params[:return_to] == "class") ? "class" : "sheet"

    def refused(code, resume_at = nil)
      @error_code = code
      @resume_at = resume_at
      @exercise_public_id = exercise_public_id
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.html { back_to_lesson(alert: error_text(code, resume_at)) }
      end
    end

    def back_to_lesson(alert: nil)
      redirect_to course_path(course_slug, anchor: "sheet-exercise-#{exercise_public_id}"), alert:, status: :see_other
    end

    def course_slug = @course_slug ||= Queries::Assessment::ExerciseDetailQuery.new.call(public_id: exercise_public_id, reveal: false).course.slug

    # :paused (resume_at), :assigned_pending (CA-17), :assignment_closed (devoir déjà rendu), :archived (exercice absent ou archivé),
    # :invalid_copy (une réponse refusée par la copie : pas un nombre, trop longue, mauvaise sélection), sinon :failed.
    def error_code(result)
      base = result.errors.fetch(:base, [])
      return :paused if base.include?(:paused)
      return :assigned_pending if base.include?(:assigned_pending)
      return :assignment_closed if base.include?(:assignment_closed)
      return :invalid_copy if result.code == :invalid

      result.code == :not_found || base.include?(:exercise_archived) ? :archived : :failed
    end

    def error_text(code, resume_at)
      case code
      when :paused then t("assessment.sheet_checks.errors.paused", time: l(resume_at, format: :hour_minute))
      when :assigned_pending then t("assessment.sheet_checks.errors.assigned_pending_html", link: t("assessment.sheet_checks.class_link"))
      when :assignment_closed then t("assessment.sheet_checks.errors.assignment_closed")
      when :archived then t("assessment.sheet_checks.errors.archived")
      when :invalid_copy then t("assessment.sheet_checks.errors.invalid_copy")
      else t("assessment.sheet_checks.errors.failed")
      end
    end

    def check_exercise
      sessions = Repositories::Assessment::ExerciseSessionRepository.new
      exercises = Repositories::Assessment::ExerciseRepository.new
      transaction = Repositories::Shared::Transaction.new
      policy = Policies::Assessment::SubmitAttemptPolicy.new
      UseCases::Assessment::CheckExerciseOnSheet.new(
        start: UseCases::Assessment::StartExerciseSession.new(
          exercises:, sessions:, gaps: Repositories::Assessment::KnowledgeGapRepository.new,
          memberships: Repositories::Classroom::MembershipRepository.new, assignments: Repositories::Classroom::AssignmentRepository.new,
          policy: Policies::Assessment::StartSessionPolicy.new, transaction:, clock: Time.zone
        ),
        submit: UseCases::Assessment::SubmitExerciseCopy.new(
          sessions:, exercises:, policy:, transaction:, clock: Time.zone,
          close: UseCases::Assessment::CloseExerciseSession.new(
            sessions:, exercises:, badges: Repositories::Assessment::BadgeRepository.new,
            gaps: Repositories::Assessment::KnowledgeGapRepository.new, policy:, transaction:, clock: Time.zone
          )
        ),
        exercises:, policy: Policies::Assessment::StartSessionPolicy.new, pending: Repositories::Assessment::PendingAssignmentRepository.new, transaction:,
        assignments: Repositories::Classroom::AssignmentRepository.new, memberships: Repositories::Classroom::MembershipRepository.new
      )
    end
  end
end
