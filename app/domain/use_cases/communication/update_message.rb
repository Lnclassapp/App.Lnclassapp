# 🧠 DOMAINE · UseCases::Communication::UpdateMessage
# Rôle : son auteur modifie une annonce ; publiée, elle garde ses dates et revient chez ceux qui l'avaient masquée ; sa parution suit le plafond de 3 ; elle garde son dessin de l'équipe, même retiré
# ADR  : 0028, 0045, 0078, 0081 · UDR : 0071, 0075
module UseCases
  module Communication
    class UpdateMessage
      include CreateMessage::Writing

      # policy : ManageOwnPolicy (l'auteur seul, rien de figé) ; publish_policy : PublishPolicy (pour qui, comme à la
      # création : les destinataires peuvent changer) ; illustrations : IllustrationRepositoryPort.
      def initialize(messages:, attachments:, schools:, classrooms:, teachings:, audit_log:, illustrations:, transaction:,
                     policy:, publish_policy:, clock:)
        @messages = messages
        @attachments = attachments
        @schools = schools
        @classrooms = classrooms
        @teachings = teachings
        @audit_log = audit_log
        @illustrations = illustrations
        @transaction = transaction
        @policy = policy
        @publish_policy = publish_policy
        @clock = clock
      end

      # → success(Saved : l'annonce, et les annonces archivées par sa parution) | :not_found (inconnue, ou d'un autre
      # auteur) | :conflict (figée) | :forbidden | :invalid
      def call(actor:, public_id:, dto:)
        message = @messages.find_by_public_id(public_id:)
        owned = @policy.call(actor:, message:)
        return owned if owned.failure?

        targets = targets(actor, dto)
        allowed = @publish_policy.call(actor:, **targets.to_h)
        return allowed if allowed.code == :forbidden

        now = @clock.now
        live = message if message.status == "published"
        @carried_id = message.illustration_id
        errors, illustration_id = form_errors(dto, allowed, now:, live:)
        return Shared::Result.failure(:invalid, errors:) unless errors.empty?

        @transaction.call { update(message, dto, targets, now, illustration_id, live: !live.nil?) }
      rescue Frozen
        Shared::Result.failure(:conflict)
      end

      private

      # Décision du chantier annonces-v2 (Lot E) : le dessin de l'équipe qu'une annonce porte reste servi jusqu'à sa fin
      # (AV-10) ; la modification le garde donc, même retiré depuis. Seul le nouveau choix d'un dessin retiré est refusé.
      # @carried_id : le dessin que porte l'annonce lue par cet appel, ou nil. → son id | celui de Writing
      def library_illustration_id(dto)
        return super unless @carried_id && dto.library_illustration?

        @illustrations.find_by_public_id(public_id: dto.illustration)&.id == @carried_id ? @carried_id : super
      end

      # Publiée : ses dates gardées, edited_at et rejets effacés dans la même transaction (ADR-0078 §4.1, AN-14), rien
      # d'archivé. Brouillon ou programmée qui paraît maintenant : une parution, sous le plafond (ADR-0081 §4.1), et
      # journalisée comme une publication.
      def update(message, dto, targets, now, illustration_id, live:)
        archived = !live && dto.status == "published" ? make_room(message.author_id, now) : []
        saved = @messages.update(message: message.with(**written(dto, targets, illustration_id), edited_at: (now if live)))
        # Archivée ou retirée depuis la lecture : rien n'est écrit, et les archivages du plafond sont annulés.
        raise Frozen if saved.nil?

        @messages.clear_dismissals(message_id: message.id) if live
        store_files(message.id, dto)
        journal_publication(saved, now) if !live && saved.status == "published"
        Shared::Result.success(Saved.new(message: saved, archived:))
      end
    end
  end
end
