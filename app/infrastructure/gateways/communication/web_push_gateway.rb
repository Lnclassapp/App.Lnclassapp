# 🔌 INFRA · Gateways::Communication::WebPushGateway
# Rôle : envoie une notification à un navigateur par Web Push (gem web-push, VAPID) ; répond par un symbole du port pour tout échec de réseau ou de service ; un bug (autre exception) lève
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
      rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription => error
        log(:info, :gone, subscription, error)
        :gone
      rescue WebPush::Unauthorized => error
        # 401/403 : les clés VAPID sont suspectes, jamais un abonnement mort ; l'abonnement reste, l'équipe doit le voir.
        log(:error, :retry, subscription, error)
        :retry
      rescue WebPush::PayloadTooLarge, ArgumentError, OpenSSL::PKey::PKeyError => error
        # 413 et clés d'abonnement illisibles : cet abonnement ne marchera jamais.
        log(:warn, :gone, subscription, error)
        :gone
      rescue WebPush::ResponseError => error
        # 400 : requête refusée par le service, abonnement inutilisable ; toute autre réponse inattendue : à retenter.
        status = error.response.code == "400" ? :gone : :retry
        log(:warn, status, subscription, error)
        status
      rescue WebPush::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
        log(:warn, :retry, subscription, error)
        :retry
      end

      private

      # Ni charge, ni clé, ni adresse entière : l'identifiant de l'abonnement, la classe de l'erreur, le code HTTP et l'hôte du service.
      def log(level, status, subscription, error)
        host = subscription.endpoint[%r{\Ahttps://([^/:?#]+)}, 1].to_s
        Rails.logger.public_send(level, "[#{self.class.name}] #{status}: #{error.class.name} subscription=#{subscription.id} " \
                                        "code=#{error.try(:response)&.code || '-'} host=#{host}")
      end

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
