# 🌐 DELIVERY · Teams::AnnouncementIllustrationRetirementsController
# Rôle : l'équipe retire une illustration du choix des auteurs, depuis la confirmation du menu ⋮ ; redirection et toast
# ADR  : 0026, 0028, 0081 (§4.3) · UDR : 0075 (§3.5) · garde : celle de BaseController (équipe seule, 403 sinon)
module Teams
  class AnnouncementIllustrationRetirementsController < BaseController
    # Une illustration de base ou inconnue : 404 (AV-10). Les annonces qui portent l'illustration la gardent.
    def create
      result = retire.call(actor: current_actor, public_id: params[:public_id])
      render_result result, success: lambda { |_|
        redirect_to teams_announcement_illustrations_path, notice: t(".retired"), status: :see_other
      }
    end

    private

    def retire
      UseCases::Communication::RetireIllustration.new(
        illustrations: Repositories::Communication::IllustrationRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy: Policies::Communication::ManageIllustrationsPolicy.new, clock: Time.zone
      )
    end
  end
end
