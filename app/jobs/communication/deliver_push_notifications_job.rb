# 🔌 INFRASTRUCTURE · Communication::DeliverPushNotificationsJob
# Rôle : toutes les 15 minutes, un passage d'envoi des notifications Web Push aux élèves, sur les adaptateurs réels
# ADR  : 0146 (§3.2, §4.3)
module Communication
  class DeliverPushNotificationsJob < ApplicationJob
    DEFAULT_MIN_INTERVAL_HOURS = 4

    # Un seul passage à la fois : deux passages en parallèle enverraient deux fois la même notification.
    limits_concurrency to: 1, key: -> { self.class.name }

    # Le résultat est journalisé, vide compris : un passage muet ne se distingue pas d'un passage qui ne tourne pas.
    def perform
      result = UseCases::Communication::DeliverPushNotifications.new(
        candidates: Queries::Communication::PushCandidates.new, subscriptions: Repositories::Communication::PushSubscriptionRepository.new,
        preferences: Repositories::Communication::PushPreferenceRepository.new, deliveries: Repositories::Communication::PushDeliveryRepository.new,
        gateway: Gateways::Communication::WebPushGateway.new, clock: Time.zone, delivery_enabled: delivery_enabled?, min_interval: min_interval
      ).call
      Rails.logger.info("[#{self.class.name}] push notifications by status: #{result.value.inspect}")
      Rails.logger.warn("[#{self.class.name}] #{result.value['not_configured']} student(s) not notified: VAPID keys are missing") if result.value["not_configured"].to_i.positive?
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
