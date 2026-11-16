# 🔌 INFRA · Repositories::Communication::PushDataEraser
# Rôle : efface les abonnements, la préférence et les envois push d'un élève anonymisé (push_subscriptions, push_preferences, push_deliveries)
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.3), 0036 (amendement) · adaptateur de Ports::Communication::PushDataEraserPort
module Repositories
  module Communication
    class PushDataEraser
      include Ports::Communication::PushDataEraserPort

      def erase_for(user_id:)
        Orm::Communication::PushSubscription.where(user_id:).delete_all
        Orm::Communication::PushPreference.where(user_id:).delete_all
        Orm::Communication::PushDelivery.where(user_id:).delete_all
        true
      end
    end
  end
end
