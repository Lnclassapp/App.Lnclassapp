# 🧠 DOMAINE · UseCases::Communication::UpdateMessage
# Rôle : son auteur modifie une annonce ; publiée, elle garde ses dates et revient chez ceux qui l'avaient masquée ; sa parution suit le plafond de 3, une fois ; elle garde son dessin de l'équipe et sa case « Prévenir les élèves »
# ADR  : 0028, 0045, 0078, 0081, 0094, 0147 · UDR : 0071, 0075, 0187
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
        errors, illustration_id = form_errors(dto, allowed, now:, live:, carried_id: message.illustration_id)
        return Shared::Result.failure(:invalid, errors:) unless errors.empty?

        @transaction.call do
          live ? modify(message, dto, targets, now, illustration_id, actor) : save(message, dto, targets, now, illustration_id, actor)
        end
      rescue Frozen
        Shared::Result.failure(:conflict)
      end

      private

      # Brouillon ou programmée à la lecture : relue sous le verrou de l'auteur. Parue entre-temps (« Publier » envoyé
      # deux fois, ou le passage du job), la saisie s'applique comme la modification de l'annonce en ligne : rien n'est
      # archivé ni journalisé une seconde fois (phase 5, F1). Sinon, une parution suit le plafond (ADR-0081 §4.1) et se
      # journalise ; un brouillon ou une programmée n'archive rien.
      def save(read, dto, targets, now, illustration_id, actor)
        live = lock_author(read.author_id, now, read.cap_school_id)
        message = @messages.find_by_public_id(public_id: read.public_id)
        return modify(message, dto, targets, now, illustration_id, actor) if message.status == "published"

        archived = dto.status == "published" ? make_room(live) : []
        saved = write(message.with(**written(dto, targets, illustration_id, actor)))
        store_files(message.id, dto)
        journal_publication(saved, now) if saved.status == "published"
        Shared::Result.success(Saved.new(message: saved, archived:))
      end

      # Publiée : ses dates gardées (la saisie est relue avec elles), edited_at et rejets effacés dans la même
      # transaction (ADR-0078 §4.1, AN-14), rien d'archivé ni de journalisé. La case « Prévenir les élèves » est figée
      # à la publication (ADR-0147 §4.1, décision du porteur du 2026-11-27) : la saisie ne peut ni la cocher ni la décocher.
      def modify(message, dto, targets, now, illustration_id, actor)
        dto.valid_at?(now:, live_since: message.published_at, live_until: message.ends_at)
        saved = write(message.with(**written(dto, targets, illustration_id, actor), push_requested: message.push_requested, edited_at: now))
        @messages.clear_dismissals(message_id: message.id)
        store_files(message.id, dto)
        Shared::Result.success(Saved.new(message: saved, archived: []))
      end

      # Archivée ou retirée depuis la lecture : rien n'est écrit, et les archivages du plafond sont annulés.
      def write(message) = @messages.update(message:) || raise(Frozen)
    end
  end
end
