# 🧠 DOMAINE · UseCases::Communication::ArchiveMessage
# Rôle : son auteur archive une annonce (brouillon, programmée ou publiée) : elle disparaît pour tous et devient figée
# ADR  : 0028, 0045, 0078 · UDR : 0071
module UseCases
  module Communication
    class ArchiveMessage
      def initialize(messages:, policy:)
        @messages = messages
        @policy = policy
      end

      # → success(Message) | :not_found (inconnue, ou d'un autre auteur) | :conflict (archivée ou retirée, même depuis la lecture)
      def call(actor:, public_id:)
        message = @messages.find_by_public_id(public_id:)
        allowed = @policy.call(actor:, message:)
        return allowed if allowed.failure?

        # Une seule écriture : la date de fin d'une annonce déjà en ligne est gardée, un brouillon n'en a pas. Retirée
        # depuis la lecture : rien n'est écrit.
        archived = @messages.update(message: message.with(status: "archived"))
        archived ? Shared::Result.success(archived) : Shared::Result.failure(:conflict)
      end
    end
  end
end
