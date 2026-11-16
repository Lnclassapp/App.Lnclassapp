# 🧠 DOMAINE · Entities::Communication::PushSubscription
# Rôle : un abonnement Web Push d'un navigateur : adresse et deux clés, rien d'autre
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.1)
module Entities
  module Communication
    PushSubscription = Data.define(:id, :user_id, :session_id, :endpoint, :p256dh, :auth, :last_success_at, :failure_count) do
      def initialize(user_id:, endpoint:, p256dh:, auth:, id: nil, session_id: nil, last_success_at: nil, failure_count: 0) = super
    end
  end
end
