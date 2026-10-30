# 🌐 DELIVERY · Assessment::ExerciseCopiesController
# Rôle : l'élève rend sa copie d'un seul envoi : 303 vers le résultat, 422 avec ses réponses réaffichées, retrait de l'exercice vers la leçon
# ADR  : 0026, 0054, 0091 (§4.4 : texte ou indices d'affichage), 0112, 0115, XXXX-questions-a-plusieurs-cases-et-indice (§4 : params blanks) · UDR : 0138 §3.3 · sécurité : copy[answers][<id>] lu champ par champ
module Assessment
  class ExerciseCopiesController < AuthenticatedController
    include ReadsOwnLevel

    allow_roles :student

    ATTRIBUTES = "activemodel.errors.models.dtos/assessment/attempt_input.attributes".freeze

    # Sa propre copie hors niveau (ouverte avant la règle de l'UDR-0013, 2026-10-01) ne se rend plus : 404. La copie d'un autre
    # élève reste refusée par le use case (403), sans rien dire de son niveau.
    def create
      return if own_session? && refuse_out_of_level(session_public_id: params[:public_id])

      @form = Dtos::Assessment::CopyInput.new(session_public_id: params[:public_id], answers: posted_answers)
      result = submit_copy.call(actor: current_actor, dto: @form)
      return refuse_copy(result) if result.code == :invalid
      return leave_copy(result) if result.code == :conflict

      render_result result, success: lambda { |submitted|
        redirect_to exercise_session_result_path(submitted.session_public_id), status: :see_other
      }
    end

    private

    def own_session?
      Repositories::Assessment::ExerciseSessionRepository.new.find_by_public_id(public_id: params[:public_id])&.student_id ==
        current_actor.user_id
    end

    # Ce que l'élève a posté, champ par champ : ni plus de quatre champs par question, ni autre clé que celles que le DTO lit.
    def posted_answers
      copy = params[:copy]
      answers = copy[:answers] if copy.is_a?(ActionController::Parameters)
      return {} unless answers.is_a?(ActionController::Parameters)

      answers.to_unsafe_h.transform_values do |fields|
        fields.is_a?(Hash) ? fields.slice(*Dtos::Assessment::CopyInput::FIELDS.map(&:to_s)) : {}
      end
    end

    # La copie se rouvre avec les valeurs postées et le message de chaque question en cause ; rien n'a été noté.
    def refuse_copy(result)
      @play = Queries::Assessment::SessionPlayQuery.new.copy(public_id: params[:public_id])
      @posted = posted_answers
      @copy_errors = result.errors.to_h { |number, fields| [ number, messages(number, fields) ] }
      render "assessment/exercise_sessions/show", status: :unprocessable_entity
    end

    def messages(number, fields)
      return [ t("errors.codes.invalid") ] if number == :base

      fields.flat_map { |attribute, codes| codes.map { t("#{ATTRIBUTES}.#{attribute}.#{it}", count: Dtos::Assessment::AttemptInput::RESPONSE_TEXT_MAX) } }.uniq
    end

    # Exercice archivé : retour à la leçon. Copie abandonnée (« Recommencer » dans un autre onglet) : retour à l'exercice.
    def leave_copy(result)
      return redirect_to exercise_path(exercise_public_id), alert: t("assessment.exercise_sessions.show.abandoned"), status: :see_other unless
        result.errors.fetch(:base, []).include?(:exercise_archived)

      detail = Queries::Assessment::ExerciseDetailQuery.new.call(public_id: exercise_public_id, reveal: false)
      anchor = detail.essential ? "notion-#{detail.essential.slug}" : "toute-la-lecon"
      redirect_to course_path(detail.course.slug, anchor:), alert: t(".archived"), status: :see_other
    end

    def exercise_public_id = Queries::Assessment::SessionPlayQuery.new.copy(public_id: params[:public_id]).exercise_public_id

    def submit_copy
      sessions = Repositories::Assessment::ExerciseSessionRepository.new
      transaction = Repositories::Shared::Transaction.new
      UseCases::Assessment::SubmitExerciseCopy.new(
        sessions:, exercises: Repositories::Assessment::ExerciseRepository.new, policy: Policies::Assessment::SubmitAttemptPolicy.new,
        close: UseCases::Assessment::CloseExerciseSession.new(
          sessions:, exercises: Repositories::Assessment::ExerciseRepository.new,
          badges: Repositories::Assessment::BadgeRepository.new, gaps: Repositories::Assessment::KnowledgeGapRepository.new,
          policy: Policies::Assessment::SubmitAttemptPolicy.new, transaction:, clock: Time.zone
        ),
        transaction:, clock: Time.zone
      )
    end
  end
end
