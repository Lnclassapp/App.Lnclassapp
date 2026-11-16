# 🧠 DOMAINE · UseCases::Communication::PurgePushData
# Rôle : supprime les abonnements sans envoi réussi depuis 60 jours et les envois de plus de 90 jours
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.1) · sans acteur ni policy (job) : exemption de test/architecture/use_case_policies_test.rb
module UseCases
  module Communication
    class PurgePushData
      SUBSCRIPTION_TTL = 60.days
      DELIVERY_TTL = 90.days

      def initialize(subscriptions:, deliveries:, clock:)
        @subscriptions = subscriptions
        @deliveries = deliveries
        @clock = clock
      end

      # → success({ subscriptions: n, deliveries: m })
      def call
        now = @clock.now
        Shared::Result.success(subscriptions: @subscriptions.delete_stale(before: now - SUBSCRIPTION_TTL),
                               deliveries: @deliveries.purge_before(before: now - DELIVERY_TTL))
      end
    end
  end
end
