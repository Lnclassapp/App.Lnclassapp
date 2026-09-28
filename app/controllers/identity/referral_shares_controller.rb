# 🌐 DELIVERY · Identity::ReferralSharesController
# Rôle : enregistre un clic « Partager » (sendBeacon) d'un enseignant d'un établissement actif ; 204, aucun cookie posé
# ADR  : 0028, 0049, 0063 · UDR : 0050
module Identity
  class ReferralSharesController < AuthenticatedController
    def create
      result = UseCases::Identity::RecordReferralShare.new(
        referrals: Repositories::Identity::ReferralRepository.new, schools: Repositories::School::SchoolRepository.new,
        policy: Policies::Identity::InviteColleaguePolicy.new, clock: Time.zone
      ).call(actor: current_actor, channel: params[:channel].to_s)
      return head :no_content if result.success?
      return head :unprocessable_entity if result.code == :invalid

      render_forbidden
    end
  end
end
