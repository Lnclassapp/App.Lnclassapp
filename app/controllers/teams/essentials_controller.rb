# 🌐 DELIVERY · Teams::EssentialsController
# Rôle : notions d'une leçon : publication (seule ou avec ses exercices) et archivage ; plus de création ni de modification à l'écran (CA-29)
# ADR  : 0026, 0028, 0035, 0113 (§4.6) · UDR : 0006, 0007, 0129
module Teams
  class EssentialsController < BaseController
    include PublishCascade

    def publish = transition(publish_essential)
    def archive = transition(archive_essential)

    private

    def cascade_root = :essential

    # Refus (cours non publié, transition interdite) : 422 et toast d'erreur, le panneau de statut reste tel quel. Sans Turbo,
    # retour à la page d'où le bouton a été cliqué.
    def transition(use_case)
      result = use_case.call(actor: current_actor, slug: params[:slug])
      @reason = result.errors.fetch(:base).first if result.code == :conflict
      return respond_transition(:unprocessable_entity, alert: t("teams.essentials.transition.#{@reason}")) if @reason

      render_result result, success: lambda { |essential|
        @essential = essential
        respond_transition(:ok, notice: t("teams.essentials.transition.#{essential.status}", name: essential.name))
      }
    end

    def respond_transition(status, **flash)
      respond_to do |format|
        format.turbo_stream { render :transition, status: }
        format.html { redirect_back_or_to courses_path, **flash, status: :see_other }
      end
    end

    def essential_repository = Repositories::Catalog::EssentialRepository.new

    def publish_essential = UseCases::Catalog::PublishEssential.new(**transition_dependencies)
    def archive_essential = UseCases::Catalog::ArchiveEssential.new(**transition_dependencies)

    def transition_dependencies
      { essentials: essential_repository, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy:, clock: Time.zone }
    end

    def policy = Policies::Catalog::ManageContentPolicy.new
  end
end
