# 🌐 DELIVERY · Communication::MessageArchivesController
# Rôle : son auteur archive une annonce après confirmation ; retour à « Mes annonces » avec un toast ; 404 pour tout autre
# ADR  : 0026, 0028, 0078 · UDR : 0071 (§3.7)
module Communication
  class MessageArchivesController < AuthenticatedController
    allow_roles :teacher, :school_admin, :team

    def create
      result = archive.call(actor: current_actor, public_id: params[:public_id])
      return redirect_to(my_announcements_path, alert: t(".frozen"), status: :see_other) if result.code == :conflict

      render_result result, success: ->(_) { redirect_to my_announcements_path, notice: t(".archived"), status: :see_other }
    end

    private

    def archive
      UseCases::Communication::ArchiveMessage.new(messages: Repositories::Communication::MessageRepository.new,
                                                  policy: Policies::Communication::ManageOwnPolicy.new)
    end
  end
end
