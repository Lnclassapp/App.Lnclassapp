# 🧠 DOMAINE · UseCases::Communication::UpdateMessage
# Rôle : son auteur modifie une annonce ; publiée, elle garde sa date, est marquée modifiée et revient chez ceux qui l'avaient masquée
# ADR  : 0028, 0045, 0078 · UDR : 0071
module UseCases
  module Communication
    class UpdateMessage
      include CreateMessage::Writing

      # policy : ManageOwnPolicy (l'auteur seul, rien de figé) ; publish_policy : PublishPolicy (pour qui, comme à la
      # création : les destinataires peuvent changer).
      def initialize(messages:, attachments:, schools:, classrooms:, teachings:, audit_log:, transaction:, policy:,
                     publish_policy:, clock:)
        @messages = messages
        @attachments = attachments
        @schools = schools
        @classrooms = classrooms
        @teachings = teachings
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @publish_policy = publish_policy
        @clock = clock
      end

      # → success(Message) | :not_found (inconnue, ou d'un autre auteur) | :conflict (figée) | :forbidden | :invalid
      def call(actor:, public_id:, dto:)
        message = @messages.find_by_public_id(public_id:)
        owned = @policy.call(actor:, message:)
        return owned if owned.failure?

        targets = targets(actor, dto)
        allowed = @publish_policy.call(actor:, **targets.to_h)
        return allowed if allowed.code == :forbidden

        now = @clock.now
        live_since = message.published_at if message.status == "published"
        errors = form_errors(dto, allowed, now:, live_since:)
        return Shared::Result.failure(:invalid, errors:) unless errors.empty?

        @transaction.call { update(message, dto, targets, now, live: !live_since.nil?) }
      end

      private

      # Publiée : edited_at et rejets effacés dans la même transaction (ADR-0078 §4.1, AN-14). Brouillon ou programmée
      # qui paraît maintenant : journalisée comme une publication.
      def update(message, dto, targets, now, live:)
        saved = @messages.update(message: message.with(
          title: dto.title, body: dto.body, audience: targets.audience, school_id: targets.school_id,
          classroom_ids: targets.classroom_ids, illustration: dto.illustration, status: dto.status,
          published_at: dto.publication_time, ends_at: dto.ends_at, edited_at: (now if live)
        ))
        @messages.clear_dismissals(message_id: message.id) if live
        store_files(message.id, dto)
        journal_publication(saved, now) if !live && saved.status == "published"
        Shared::Result.success(saved)
      end
    end
  end
end
