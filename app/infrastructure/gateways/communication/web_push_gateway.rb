# 🔌 INFRA · Gateways::Communication::WebPushGateway
# Rôle : envoie une notification à un navigateur par Web Push (gem web-push, VAPID) ; ne lève jamais, répond par un symbole du port
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.2, §4.3) · adaptateur de Ports::Communication::PushGatewayPort
module Gateways
  module Communication
    class WebPushGateway
      include Ports::Communication::PushGatewayPort

      TTL = 12.hours.to_i
      URGENCY = "normal".freeze
      OPEN_TIMEOUT = 5
      READ_TIMEOUT = 10

      # La gem n'écrit pas l'en-tête Topic (RFC 8030 §5.4) : une nouvelle notification du même motif remplace celle qui attend.
      class TopicRequest < WebPush::Request
        def initialize(topic:, **options)
          super(**options)
          @topic = topic
        end

        def headers = super.merge("Topic" => @topic)
      end

      # Les clés sont lues à chaque appel : une variable posée après le démarrage est prise en compte.
      def deliver(subscription:, message:)
        vapid = vapid_options
        return :not_configured if vapid.nil?

        request(subscription, message, vapid).perform
        :delivered
      rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
        :gone
      rescue StandardError => error
        # Ni charge ni clé dans le journal : la classe de l'erreur suffit à diagnostiquer.
        Rails.logger.warn("[#{self.class.name}] retry: #{error.class.name}")
        :retry
      end

      private

      def vapid_options
        options = { public_key: ENV["VAPID_PUBLIC_KEY"], private_key: ENV["VAPID_PRIVATE_KEY"], subject: ENV["VAPID_SUBJECT"] }
        options if options.values.all?(&:present?)
      end

      def request(subscription, message, vapid)
        TopicRequest.new(topic: message.tag, message: message.to_h.slice(:title, :body, :url, :tag).to_json,
                         subscription: { endpoint: subscription.endpoint, keys: { p256dh: subscription.p256dh, auth: subscription.auth } },
                         vapid:, ttl: TTL, urgency: URGENCY, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, ssl_timeout: OPEN_TIMEOUT)
      end
    end
  end
end
