# 🧠 DOMAINE · UseCases::Communication::RegisterPushSubscription
# Rôle : l'élève enregistre l'abonnement Web Push de son navigateur, rattaché à sa session courante (jamais à un identifiant du client) ; une adresse connue change de propriétaire
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.2, §4.3)
module UseCases
  module Communication
    class RegisterPushSubscription
      MAX_ENDPOINT = 2048
      MAX_KEY = 255
      # L'adresse est appelée par le serveur à l'envoi : https seulement, un nom de domaine, ni identifiant, ni adresse locale.
      HOST = /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+\z/i

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

        Shared::Result.success(@subscriptions.register(user_id: actor.user_id, session_id:, endpoint:, p256dh:, auth:))
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
        uri.is_a?(URI::HTTPS) && uri.userinfo.nil? && uri.host.to_s.match?(HOST) && !uri.host.match?(/\A[\d.]+\z/) && uri.host != "localhost"
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
