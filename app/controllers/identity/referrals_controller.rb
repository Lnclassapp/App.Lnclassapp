# 🌐 DELIVERY · Identity::ReferralsController
# Rôle : page « Inviter un collègue » (fermée sans établissement actif)
# ADR  : 0028, 0063, 0094 (§11) · UDR : 0050, 0069 (§3.6), 0098 (§3.6)
module Identity
  class ReferralsController < AuthenticatedController
    include ColleagueInvitation

    allow_roles :teacher

    def show
      @invite = colleague_invite
    end
  end
end
