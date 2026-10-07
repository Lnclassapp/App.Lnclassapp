# 🧠 DOMAINE · UseCases::Communication::DismissMessage
# Rôle : un élève masque une annonce qu'il lit, sur tous ses appareils ; une annonce officielle ou illisible est refusée
# ADR  : 0028, 0045, 0078 (§4.2) · UDR : 0071 (§3.5)
module UseCases
  module Communication
    class DismissMessage
      def initialize(messages:, readable:, dismissals:, policy:, clock:)
        @messages = messages
        @readable = readable
        @dismissals = dismissals
        @policy = policy
        @clock = clock
      end

      # → success(Entities::Communication::Message) | :not_found | :forbidden (rien n'est écrit)
      def call(actor:, public_id:)
        message = @messages.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if message.nil?

        now = @clock.now
        readable = @readable.readable?(reader: @readable.reader_for(actor:), public_id:, now:)
        allowed = @policy.call(actor:, readable:, author_role: @messages.author_role(message:))
        return allowed if allowed.failure?

        @dismissals.dismiss(message_id: message.id, user_id: actor.user_id, at: now)
        Shared::Result.success(message)
      end
    end
  end
end
