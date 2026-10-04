# 🧠 DOMAINE · UseCases::Communication::PublishScheduledMessages
# Rôle : publie les annonces programmées dont l'heure est venue, chacune journalisée avec son auteur pour acteur
# ADR  : 0045, 0078 · sans acteur ni policy (job) : exemption de test/architecture/use_case_policies_test.rb
module UseCases
  module Communication
    class PublishScheduledMessages
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

      # Relue dans sa transaction : une annonce archivée, modifiée ou reprogrammée depuis la lecture de la liste n'est
      # pas réécrite. → true si elle est publiée
      def publish(due, now)
        @transaction.call do
          message = @messages.find_by_public_id(public_id: due.public_id)
          next false unless message.status == "scheduled" && message.published_at <= now

          @messages.update(message: message.with(status: "published"))
          @audit_log.record(action: "message.published", actor_id: message.author_id, at: now, subject_type: "Message",
                            subject_id: message.id)
          true
        end
      end
    end
  end
end
