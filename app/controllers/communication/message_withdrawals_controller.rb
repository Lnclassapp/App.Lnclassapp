# 🌐 DELIVERY · Communication::MessageWithdrawalsController
# Rôle : l'équipe ou la direction retire une annonce après confirmation : la ligne part et un toast le dit ; 404 hors droit
# ADR  : 0026, 0028, 0078 (§4.2, §4.5) · UDR : 0071 (§3.7)
module Communication
  class MessageWithdrawalsController < AuthenticatedController
    # L'enseignant entre pour recevoir le 404 de WithdrawPolicy (AN-17, ADR-0078 §4.2) ; l'élève reçoit 403.
    allow_roles :teacher, :school_admin, :team

    def create
      result = withdraw.call(actor: current_actor, public_id: params[:public_id])
      # Déjà archivée ou retirée : elle n'est plus retirable, 404 comme hors droit (UDR-0071, États obligatoires).
      return render_not_found if result.code == :conflict

      render_result result, success: lambda { |message|
        @message = message
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to moderated_announcements_path, notice: t(".withdrawn"), status: :see_other }
        end
      }
    end

    private

    def withdraw
      UseCases::Communication::WithdrawMessage.new(
        messages: Repositories::Communication::MessageRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy: Policies::Communication::WithdrawPolicy.new, clock: Time.zone
      )
    end
  end
end
