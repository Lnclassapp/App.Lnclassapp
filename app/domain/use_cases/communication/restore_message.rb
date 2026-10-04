# 🧠 DOMAINE · UseCases::Communication::RestoreMessage
# Rôle : « Annuler » et « Réafficher » : l'élève reprend une annonce qu'il avait masquée, sous le même droit que pour la masquer
# ADR  : 0028, 0078 (§4.2) · UDR : 0071 (§3.5, §3.7)
module UseCases
  module Communication
    class RestoreMessage
      def initialize(messages:, readable:, dismissals:, policy:, clock:)
        @messages = messages
        @readable = readable
        @dismissals = dismissals
        @policy = policy
        @clock = clock
      end

      # → success(Entities::Communication::Message) | :not_found | :forbidden (rien n'est effacé)
      def call(actor:, public_id:)
        message = @messages.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if message.nil?

        readable = @readable.readable?(reader: @readable.reader_for(actor:), public_id:, now: @clock.now)
        allowed = @policy.call(actor:, readable:, author_role: @messages.author_role(message:))
        return allowed if allowed.failure?

        @dismissals.restore(message_id: message.id, user_id: actor.user_id)
        Shared::Result.success(message)
      end
    end
  end
end
