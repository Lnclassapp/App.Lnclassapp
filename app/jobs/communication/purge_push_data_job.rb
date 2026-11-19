# 🔌 INFRASTRUCTURE · Communication::PurgePushDataJob
# Rôle : supprime chaque jour les abonnements Web Push sans envoi réussi depuis 60 jours et les envois de plus de 90 jours
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.1)
module Communication
  class PurgePushDataJob < ApplicationJob
    # Les nombres supprimés sont journalisés, zéro compris : une purge muette ne se distingue pas d'une purge qui ne tourne pas.
    def perform
      result = UseCases::Communication::PurgePushData.new(
        subscriptions: Repositories::Communication::PushSubscriptionRepository.new,
        deliveries: Repositories::Communication::PushDeliveryRepository.new, clock: Time.zone
      ).call
      Rails.logger.info("[#{self.class.name}] #{result.value[:subscriptions]} stale push subscription(s) and #{result.value[:deliveries]} old push delivery(ies) deleted")
      result.value
    end
  end
end
