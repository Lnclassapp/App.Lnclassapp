# 🔌 INFRA · Orm::Communication::PushDelivery
# Rôle : table push_deliveries : un envoi par élève, motif et clé d'objet (anti-doublon, intervalle, pilotage), gardé 90 jours
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.1)
module Orm
  module Communication
    class PushDelivery < ApplicationRecord
      self.table_name = "push_deliveries"

      belongs_to :user, class_name: "Orm::User"

      validates :motive, :object_key, :sent_at, :status, presence: true
    end
  end
end
