# 🧠 DOMAINE · UseCases::Communication::PublishScheduledMessages
# Rôle : publie les annonces programmées dont l'heure est venue, chacune sous le plafond de 3 de son auteur et journalisée
# ADR  : 0045, 0078, 0081 · sans acteur ni policy (job) : exemption de test/architecture/use_case_policies_test.rb
module UseCases
  module Communication
    class PublishScheduledMessages
      include CreateMessage::Parution

      def initialize(messages:, audit_log:, transaction:, clock:)
        @messages = messages
        @audit_log = audit_log
        @transaction = transaction
        @clock = clock
      end

      # → success(nombre d'annonces publiées)
      def call
        now = @clock.now
        published = @messages.due_for_publication(now:).count { publish(it, now) }
        Shared::Result.success(published)
      end

      private

      # Le verrou de l'auteur d'abord, puis l'annonce relue (phase 5, F1) : archivée, reprogrammée ou déjà publiée par
      # son auteur depuis la lecture de la liste, elle n'est pas réécrite. Sa parution archive d'abord les plus anciennes
      # en ligne de son auteur (ADR-0081 §4.1). → true si elle est publiée
      def publish(due, now)
        @transaction.call do
          live = lock_author(due.author_id, now)
          message = @messages.find_by_public_id(public_id: due.public_id)
          next false unless message.status == "scheduled" && message.published_at <= now

          make_room(live)
          # Archivée ou retirée entre cette lecture et l'écriture : rien n'est écrit, ni archivé, ni journalisé.
          raise Frozen unless @messages.update(message: message.with(status: "published"))

          @audit_log.record(action: "message.published", actor_id: message.author_id, at: now, subject_type: "Message",
                            subject_id: message.id)
          true
        end
      rescue Frozen
        false
      end
    end
  end
end
