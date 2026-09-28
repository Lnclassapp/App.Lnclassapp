# 🌐 DELIVERY · Identity::ReferralSharesController
# Rôle : enregistre un clic « Partager » (sendBeacon) d'un enseignant d'un établissement actif ; 204, 30 par heure, aucun cookie
# ADR  : 0028, 0049, 0063 · UDR : 0050
module Identity
  class ReferralSharesController < AuthenticatedController
    # Un enseignant en attente reçoit le 403 de la policy (PRD), pas la redirection de l'écran d'attente.
    skip_before_action :hold_pending_teacher
    # Anti-bourrage des compteurs : 30 partages par heure et par compte.
    rate_limit to: 30, within: 1.hour, only: :create, name: "referral_shares", by: -> { current_actor.user_id },
               with: -> { head :too_many_requests }

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
