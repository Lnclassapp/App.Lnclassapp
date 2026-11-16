# 🔌 INFRASTRUCTURE · Communication::DeliverPushNotificationsJob
# Rôle : toutes les 15 minutes, un passage d'envoi des notifications Web Push aux élèves, sur les adaptateurs réels
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2, §4.3)
module Communication
  class DeliverPushNotificationsJob < ApplicationJob
    DEFAULT_MIN_INTERVAL_HOURS = 4

    # Le résultat est journalisé, vide compris : un passage muet ne se distingue pas d'un passage qui ne tourne pas.
    def perform
      result = UseCases::Communication::DeliverPushNotifications.new(
        candidates: Queries::Communication::PushCandidates.new, subscriptions: Repositories::Communication::PushSubscriptionRepository.new,
        preferences: Repositories::Communication::PushPreferenceRepository.new, deliveries: Repositories::Communication::PushDeliveryRepository.new,
        gateway: Gateways::Communication::WebPushGateway.new, clock: Time.zone, delivery_enabled: delivery_enabled?, min_interval: min_interval
      ).call
      Rails.logger.info("[#{self.class.name}] push notifications by status: #{result.value.inspect}")
      result.value
    end

    private

    # Faux par défaut : les abonnements s'enregistrent, les envois sont notés `disabled` (mise en service progressive).
    def delivery_enabled? = ActiveModel::Type::Boolean.new.cast(ENV["PUSH_DELIVERY_ENABLED"]) == true

    def min_interval
      hours = ENV["PUSH_MIN_INTERVAL_HOURS"].to_i
      (hours.positive? ? hours : DEFAULT_MIN_INTERVAL_HOURS).hours
    end
  end
end
