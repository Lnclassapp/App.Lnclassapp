# 🌐 DELIVERY · Identity::ReferralsController
# Rôle : page « Inviter un collègue » : lien personnel, partages, compteur ; fermée (état vide) sans établissement actif
# ADR  : 0028, 0063 · UDR : 0050
module Identity
  class ReferralsController < AuthenticatedController
    include ColleagueInvitation

    allow_roles :teacher

    def show
      @invite = colleague_invite
    end
  end
end
