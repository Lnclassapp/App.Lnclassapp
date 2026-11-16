# 🧠 DOMAINE · UseCases::Communication::DeliverPushNotifications
# Rôle : un passage d'envoi des notifications : fenêtre d'Abidjan, un seul motif par élève (le plus urgent), pas de doublon, 4 h entre deux envois, une ligne par navigateur
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2, §4) · sans acteur ni policy (job) : exemption de test/architecture/use_case_policies_test.rb
module UseCases
  module Communication
    class DeliverPushNotifications
      # Au troisième échec passager d'un navigateur, l'envoi est abandonné (statut `failed`).
      MAX_FAILURES = 3
      # Du statut le plus significatif au moins significatif quand plusieurs navigateurs répondent différemment.
      STATUS_ORDER = %w[delivered retry failed not_configured gone].freeze

      # candidates : PushCandidatesPort ; subscriptions, preferences, deliveries : les ports de dépôt ; gateway : PushGatewayPort ;
      # delivery_enabled : l'interrupteur PUSH_DELIVERY_ENABLED ; min_interval : durée minimale entre deux envois partis.
      def initialize(candidates:, subscriptions:, preferences:, deliveries:, gateway:, clock:, delivery_enabled:, min_interval:)
        @candidates = candidates
        @subscriptions = subscriptions
        @preferences = preferences
        @deliveries = deliveries
        @gateway = gateway
        @clock = clock
        @delivery_enabled = delivery_enabled
        @min_interval = min_interval
      end

      # → success({ "delivered" => n, … }) : le nombre d'élèves traités par statut noté ; vide hors fenêtre.
      def call
        now = @clock.now
        return Shared::Result.success({}) unless Entities::Communication::SendingWindow.open?(now)

        ready = @candidates.for(now:).reject { it.expired?(now) }.group_by(&:user_id)
        statuses = ready.filter_map { |user_id, list| deliver_to(user_id, list, now) }
        Shared::Result.success(statuses.tally)
      end

      private

      # → le statut noté, ou nil si rien n'a été fait pour cet élève.
      def deliver_to(user_id, candidates, now)
        return if @preferences.turned_off?(user_id:)

        candidate = next_candidate(user_id, candidates)
        return if candidate.nil? || too_soon?(user_id, now)

        subscriptions = @subscriptions.for_user(user_id:)
        return if subscriptions.empty?

        status = @delivery_enabled ? push(subscriptions, candidate, now) : "disabled"
        @deliveries.record(user_id:, motive: candidate.motive, object_key: candidate.object_key, status:, at: now)
        status
      end

      # Le plus urgent des motifs pas encore envoyés : un motif déjà parti ne bloque pas les suivants.
      def next_candidate(user_id, candidates)
        candidates.reject { @deliveries.sent?(user_id:, motive: it.motive, object_key: it.object_key) }.min_by(&:priority)
      end

      def too_soon?(user_id, now)
        last = @deliveries.last_sent_at(user_id:)
        !last.nil? && last > now - @min_interval
      end

      def push(subscriptions, candidate, now)
        message = Entities::Communication::PushMessage.for(candidate)
        statuses = subscriptions.map { status_of(it, @gateway.deliver(subscription: it, message:), now) }
        STATUS_ORDER.find { statuses.include?(it) }
      end

      def status_of(subscription, answer, now)
        case answer
        when :delivered
          @subscriptions.record_success(id: subscription.id, at: now)
          "delivered"
        when :gone
          @subscriptions.delete(id: subscription.id)
          "gone"
        when :retry
          @subscriptions.record_failure(id: subscription.id) >= MAX_FAILURES ? "failed" : "retry"
        else
          "not_configured"
        end
      end
    end
  end
end
