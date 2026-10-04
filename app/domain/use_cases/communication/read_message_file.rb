# 🧠 DOMAINE · UseCases::Communication::ReadMessageFile
# Rôle : lire l'image ou l'audio d'une annonce après la règle de lecture, par plage d'octets ; tout refus est not_found
# ADR  : 0028, 0047, 0069 (§4.4)
module UseCases
  module Communication
    class ReadMessageFile
      KINDS = %w[image audio].freeze

      def initialize(messages:, readable:, attachments:, policy:, clock:)
        @messages = messages
        @readable = readable
        @attachments = attachments
        @policy = policy
        @clock = clock
      end

      # range : nil (tout le fichier) ou une plage d'octets, comme AttachmentStorePort#read.
      # → success(Ports::Communication::AttachmentStorePort::StoredFile) | :not_found (inconnue, refusée, sans ce fichier)
      def call(actor:, public_id:, kind:, range: nil)
        message = @messages.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if message.nil? || !KINDS.include?(kind.to_s)

        readable = @readable.readable?(reader: @readable.reader_for(actor:), public_id:, now: @clock.now)
        allowed = @policy.call(actor:, message:, readable:, author_role: @messages.author_role(message:))
        return allowed if allowed.failure?

        file = @attachments.read(message_id: message.id, kind:, range:)
        file ? Shared::Result.success(file) : Shared::Result.failure(:not_found)
      end
    end
  end
end
