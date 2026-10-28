# 🌐 DELIVERY · Teams::ExercisesController
# Rôle : l'équipe publie ou archive un exercice ; plus de création ni de modification à l'écran, les exercices viennent de l'import (CA-29)
# ADR  : 0026, 0028, 0035, 0036, 0054, 0091, 0105, 0113 (§4.6) · UDR : 0006, 0017, 0087, 0129
module Teams
  class ExercisesController < BaseController
    def publish = change_status(publish_exercise)
    def archive = change_status(archive_exercise)

    private

    def change_status(use_case)
      result = use_case.call(actor: current_actor, public_id: params[:public_id])
      return refuse_transition(result) if result.code == :conflict

      render_result result, success: lambda { |exercise|
        @exercise = exercise
        respond_to do |format|
          format.turbo_stream { render :transition }
          format.html do
            redirect_to exercise_path(exercise.public_id), status: :see_other,
                                                           notice: t("teams.exercises.transition.#{exercise.status}", title: exercise.title)
          end
        end
      }
    end

    # Refus d'une transition (sans question, fiche non publiée, retour interdit, image manquante) : toast d'erreur qui en
    # dit la raison, et le numéro de la question en cause (ADR-0105 §4.4).
    def refuse_transition(result)
      @refusal = t("teams.exercises.transition.refusals.#{result.errors.fetch(:base).first}", number: result.errors[:number]&.first)
      respond_to do |format|
        format.turbo_stream { render :transition, status: :unprocessable_entity }
        format.html { redirect_to exercise_path(params[:public_id]), alert: @refusal, status: :see_other }
      end
    end

    def exercises = @exercises ||= Repositories::Assessment::ExerciseRepository.new

    def publish_exercise = UseCases::Assessment::PublishExercise.new(**transition_dependencies)
    def archive_exercise = UseCases::Assessment::ArchiveExercise.new(**transition_dependencies)

    def transition_dependencies
      { exercises:, audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy: manage_content, clock: Time.zone }
    end

    def manage_content = Policies::Catalog::ManageContentPolicy.new
  end
end
