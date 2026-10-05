# 🌐 DELIVERY · Identity::ReferralsController
# Rôle : page « Inviter un collègue » (fermée sans établissement actif) ; carte « Parrainage » du frame de la barre latérale
# ADR  : 0028, 0063 · UDR : 0050, 0069 (§3.6)
module Identity
  class ReferralsController < AuthenticatedController
    include ColleagueInvitation

    SIDEBAR_FRAME = "sidebar_referral".freeze

    allow_roles :teacher

    # Le frame différé de la barre latérale redemande cette page : il ne reçoit que la carte, sans layout. Invitation
    # fermée : le même frame, vide, jamais un 403 que le frame afficherait comme une erreur.
    def show
      @invite = colleague_invite
      render partial: "sidebar_card", locals: { invite: @invite } if turbo_frame_request_id == SIDEBAR_FRAME
    end
  end
end
