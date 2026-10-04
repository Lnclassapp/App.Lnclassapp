# 🧠 DOMAINE · UseCases::Communication::WithdrawMessage
# Rôle : l'équipe ou la direction retire une annonce : elle disparaît pour son audience, figée pour son auteur, et le retrait est journalisé
# ADR  : 0028, 0078 (§4.2, §4.5) · UDR : 0071 (§3.7)
module UseCases
  module Communication
    class WithdrawMessage
      def initialize(messages:, audit_log:, transaction:, policy:, clock:)
        @messages = messages
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → success(Message retirée) | :not_found (inconnue, ou hors du droit de l'acteur) | :conflict (déjà archivée ou retirée)
      def call(actor:, public_id:)
        message = @messages.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if message.nil?

        allowed = @policy.call(actor:, message:, author_role: @messages.author_role(message:))
        return allowed if allowed.failure?

        now = @clock.now
        @transaction.call { withdraw(actor, message, now) }
      end

      private

      # Le retrait et son journal ensemble : l'acteur est le modérateur, l'auteur reste nommé (ADR-0078 §4.5, sans motif).
      def withdraw(actor, message, now)
        withdrawn = @messages.update(message: message.with(status: "withdrawn", withdrawn_at: now, withdrawn_by_id: actor.user_id))
        @audit_log.record(action: "message.withdrawn", actor_id: actor.user_id, at: now, subject_type: "Message",
                          subject_id: message.id, metadata: { author_id: message.author_id })
        Shared::Result.success(withdrawn)
      end
    end
  end
end
