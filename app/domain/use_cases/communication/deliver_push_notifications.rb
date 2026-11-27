# 🧠 DOMAINE · UseCases::Communication::DeliverPushNotifications
# Rôle : un passage d'envoi des notifications : motifs cochés seulement, événements à toute heure, rappels de 6 h à 21 h (Abidjan), un motif par élève (le plus urgent), dix par jour, pas de doublon
# ADR  : 0146 (§3.2, §4) · 0147 (§4.3, amendement du 2026-11-27 II) · sans acteur ni policy (job) : exemption de test/architecture/use_case_policies_test.rb
module UseCases
  module Communication
    class DeliverPushNotifications
      # Au troisième échec passager d'un navigateur, l'envoi est abandonné (statut `failed`).
      MAX_FAILURES = 3
      # Plafond de notifications reçues par un élève sur un jour d'Abidjan (= jour UTC).
      DAILY_LIMIT = 10
      # Du statut le plus significatif au moins significatif quand plusieurs navigateurs répondent différemment.
      STATUS_ORDER = %w[delivered retry failed not_configured gone].freeze

      # candidates : PushCandidatesPort ; subscriptions, preferences, deliveries : les ports de dépôt ; gateway : PushGatewayPort ;
      # settings : PushMotiveSettingRepositoryPort ;
      # delivery_enabled : l'interrupteur PUSH_DELIVERY_ENABLED, au-dessus de toutes les règles.
      def initialize(candidates:, subscriptions:, preferences:, deliveries:, gateway:, clock:, delivery_enabled:, settings:)
        @candidates = candidates
        @subscriptions = subscriptions
        @preferences = preferences
        @deliveries = deliveries
        @gateway = gateway
        @clock = clock
        @delivery_enabled = delivery_enabled
        @settings = settings
      end

      # → success({ "delivered" => n, … }) : le nombre d'élèves traités par statut noté ; vide si aucun motif n'est ouvert.
      def call
        now = @clock.now
        open = open_motives(now)
        return Shared::Result.success({}) if open.empty?

        ready = @candidates.for(now:).reject { it.expired?(now) }.select { open.include?(it.motive) }.group_by(&:user_id)
        statuses = ready.filter_map { |user_id, list| deliver_to_safely(user_id, list, now) }
        Shared::Result.success(statuses.tally)
      end

      private

      # Un motif part si sa case est cochée ; un événement à toute heure, un rappel de 6 h à 21 h à Abidjan. L'annonce demande
      # aussi « Prévenir les élèves » à sa publication : la requête ne lit que celles-là.
      def open_motives(now)
        reminders = Entities::Communication::ReminderHours.open?(now)
        @settings.automatic_motives.select { reminders || Entities::Communication::PushMotive.event?(it) }.to_set
      end

      # Un élève dont le dépôt échoue ne bloque pas les suivants : l'erreur est signalée, le passage continue.
      def deliver_to_safely(user_id, candidates, now)
        deliver_to(user_id, candidates, now)
      rescue StandardError => error
        Rails.error.report(error, handled: true, context: { user_id:, motive: candidates.min_by(&:priority).motive })
        nil
      end

      # → le statut noté, ou nil si rien n'a été fait pour cet élève.
      def deliver_to(user_id, candidates, now)
        return if @preferences.turned_off?(user_id:) || daily_limit_reached?(user_id, now)

        candidate = next_candidate(user_id, candidates)
        return if candidate.nil?

        subscriptions = @subscriptions.for_user(user_id:)
        return if subscriptions.empty?

        candidate = still_ready(user_id, candidate, now)
        return if candidate.nil?

        send_and_record(user_id, candidate, subscriptions, now)
      end

      # PRD §3.7 : le motif est relu juste avant l'envoi, pour ce seul élève ; devenu faux depuis la sélection, rien ne part.
      def still_ready(user_id, candidate, now)
        @candidates.for(now:, user_ids: [ user_id ]).find { it.object_key == candidate.object_key && !it.expired?(now) }
      end

      # L'envoi est noté même si une écriture échoue après un envoi parti (ensure) : sans cela, l'élève le recevrait de nouveau au passage suivant.
      def send_and_record(user_id, candidate, subscriptions, now)
        statuses = []
        begin
          @delivery_enabled ? push(subscriptions, candidate, now, statuses) : statuses << "disabled"
        ensure
          write(user_id, candidate, statuses, now)
        end
        overall(statuses)
      end

      def write(user_id, candidate, statuses, now)
        return if statuses.empty?

        status = overall(statuses)
        return if @deliveries.record(user_id:, motive: candidate.motive, object_key: candidate.object_key, status:, at: now)

        Rails.logger.warn("[#{self.class.name}] delivery already recorded after a sent push: user #{user_id}, motive #{candidate.motive}") if status == "delivered"
      end

      def overall(statuses) = STATUS_ORDER.find { statuses.include?(it) } || statuses.first

      # Le plus urgent des motifs pas encore envoyés : un motif déjà parti ne bloque pas les suivants.
      def next_candidate(user_id, candidates)
        candidates.reject { @deliveries.sent?(user_id:, motive: it.motive, object_key: it.object_key) }.min_by(&:priority)
      end

      def daily_limit_reached?(user_id, now) = @deliveries.sent_count(user_id:, on_date: now.utc.to_date) >= DAILY_LIMIT

      def push(subscriptions, candidate, now, statuses)
        message = Entities::Communication::PushMessage.for(candidate)
        subscriptions.each { settle(it, @gateway.deliver(subscription: it, message:), now, statuses) }
      end

      # Le statut est noté AVANT l'écriture qui suit la réponse : si elle échoue, l'envoi parti est quand même consigné.
      def settle(subscription, answer, now, statuses)
        case answer
        when :delivered
          statuses << "delivered"
          @subscriptions.record_success(id: subscription.id, at: now)
        when :gone
          statuses << "gone"
          @subscriptions.delete(id: subscription.id)
        when :retry then statuses << failure_status(subscription)
        when :not_configured then statuses << "not_configured"
        else raise ArgumentError, "réponse de la passerelle inconnue : #{answer.inspect}"
        end
      end

      # Au troisième échec l'envoi est abandonné et le compteur repart de zéro : le motif suivant a ses 3 essais.
      def failure_status(subscription)
        return "retry" if @subscriptions.record_failure(id: subscription.id) < MAX_FAILURES

        @subscriptions.reset_failures(id: subscription.id)
        "failed"
      end
    end
  end
end
