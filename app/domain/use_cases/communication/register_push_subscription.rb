# 🧠 DOMAINE · UseCases::Communication::RegisterPushSubscription
# Rôle : l'élève enregistre l'abonnement Web Push de son navigateur, rattaché à sa session courante (jamais à un identifiant du client) ; une adresse connue change de propriétaire
# ADR  : 0146 (§4.2, §4.3)
module UseCases
  module Communication
    class RegisterPushSubscription
      MAX_ENDPOINT = 2048
      MAX_KEY = 255
      # L'adresse est appelée par le serveur à l'envoi : liste fermée des services de push des navigateurs (anti-SSRF), https sur le port 443,
      # sans identifiant. Un hôte se termine par l'un des suffixes, ou lui est égal.
      PUSH_HOSTS = %w[fcm.googleapis.com android.googleapis.com updates.push.services.mozilla.com].freeze
      PUSH_HOST_SUFFIXES = %w[.push.apple.com .notify.windows.com].freeze
      # Au-delà, l'abonnement le plus ancien de l'élève est supprimé.
      MAX_PER_USER = 5

      def initialize(users:, subscriptions:, policy:)
        @users = users
        @subscriptions = subscriptions
        @policy = policy
      end

      # → success(Entities::Communication::PushSubscription) | :forbidden | :invalid (rien n'est écrit)
      def call(actor:, session_id:, endpoint:, p256dh:, auth:)
        allowed = @policy.call(actor:, user: @users.find(id: actor&.user_id))
        return allowed if allowed.failure?

        errors = problems(endpoint:, p256dh:, auth:)
        return Shared::Result.failure(:invalid, errors:) if errors.any?

        subscription = @subscriptions.register(user_id: actor.user_id, session_id:, endpoint:, p256dh:, auth:)
        @subscriptions.delete_oldest_beyond(user_id: actor.user_id, limit: MAX_PER_USER)
        Shared::Result.success(subscription)
      end

      private

      def problems(endpoint:, p256dh:, auth:)
        { endpoint: valid_endpoint?(endpoint), p256dh: valid_key?(p256dh), auth: valid_key?(auth) }
          .reject { |_, valid| valid }.transform_values { [ :invalid ] }
      end

      def valid_key?(value) = value.is_a?(String) && value.present? && value.length <= MAX_KEY

      def valid_endpoint?(value)
        return false unless value.is_a?(String) && value.length <= MAX_ENDPOINT

        uri = URI.parse(value)
        uri.is_a?(URI::HTTPS) && uri.port == 443 && uri.userinfo.nil? && push_host?(uri.host.to_s.downcase)
      rescue URI::InvalidURIError
        false
      end

      def push_host?(host) = PUSH_HOSTS.include?(host) || PUSH_HOST_SUFFIXES.any? { host.end_with?(it) && host.length > it.length }
    end
  end
end
