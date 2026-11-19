# 🧠 DOMAINE · Policies::Communication::PushSubscriptionPolicy
# Rôle : seul un élève non anonymisé agit sur ses propres notifications (abonnement, interrupteur, report de la carte)
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.3)
module Policies
  module Communication
    class PushSubscriptionPolicy
      # user : le compte visé (Entities::Identity::User), nil s'il n'existe pas.
      def call(actor:, user:)
        return Shared::Result.failure(:forbidden) unless actor&.student? && user && !user.anonymized?
        return Shared::Result.failure(:forbidden) unless actor.user_id == user.id

        Shared::Result.success
      end
    end
  end
end
