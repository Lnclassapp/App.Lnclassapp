# 🌐 DELIVERY · Teams::SecondFactorResetsController
# Rôle : un membre de l'équipe réinitialise le second facteur d'un autre membre, depuis le résultat de la recherche d'un compte
# ADR  : 0026, 0028, 0031 · UDR : 0006, 0020
module Teams
  class SecondFactorResetsController < BaseController
    # Succès : toast et résultat de la recherche remplacé ; repli HTML : retour à la recherche du même numéro.
    def create
      render_result reset.call(actor: current_actor, target_public_id: params[:user_public_id]), success: lambda { |member|
        @member = member
        @account = Queries::Identity::AccountLookupQuery.new.call(contact: member.contact, viewer_id: current_actor.user_id)
        respond_to do |format|
          format.turbo_stream
          format.html do
            redirect_to teams_account_lookup_path(contact: member.contact), notice: t(".done", name: member.display_name),
                                                                           status: :see_other
          end
        end
      }
    end

    private

    def reset
      UseCases::Identity::ResetSecondFactor.new(
        users: Repositories::Identity::UserRepository.new, second_factors: Repositories::Identity::SecondFactorRepository.new,
        sessions: Repositories::Identity::SessionRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy: Policies::Identity::ResetSecondFactorPolicy.new,
        clock: Time.zone
      )
    end
  end
end
