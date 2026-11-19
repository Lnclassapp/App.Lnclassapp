# 🔌 INFRA · Orm::Communication::PushSubscription
# Rôle : table push_subscriptions : un abonnement Web Push d'un navigateur d'élève (adresse et deux clés, rien d'autre)
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.1)
module Orm
  module Communication
    class PushSubscription < ApplicationRecord
      self.table_name = "push_subscriptions"

      belongs_to :user, class_name: "Orm::User"
      belongs_to :session, class_name: "Orm::Session", optional: true

      validates :endpoint, :p256dh, :auth, presence: true
      validates :endpoint, uniqueness: true
    end
  end
end
