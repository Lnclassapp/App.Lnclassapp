# 🧠 DOMAINE · UseCases::Communication::PublishScheduledMessages
# Rôle : publie les annonces programmées dont l'heure est venue, chacune sous le plafond de 3 de son auteur et journalisée
# ADR  : 0045, 0078, 0081, 0094 · sans acteur ni policy (job) : exemption de test/architecture/use_case_policies_test.rb
module UseCases
  module Communication
    class PublishScheduledMessages
      include CreateMessage::Parution

      # users : UserRepositoryPort ; teachings : TeachingRepositoryPort ; policy : PublishPolicy ; teacher_flag : l'enseignant
      # peut-il encore écrire (drapeau teacher_announcements_enabled), lu à chaque passage.
      def initialize(messages:, users:, teachings:, policy:, teacher_flag:, audit_log:, transaction:, clock:)
        @messages = messages
        @users = users
        @teachings = teachings
        @policy = policy
        @teacher_flag = teacher_flag
        @audit_log = audit_log
        @transaction = transaction
        @clock = clock
      end

      # → success(nombre d'annonces publiées)
      # Une annonce en échec (exception autre que Frozen) est signalée par son id seul et laisse les suivantes partir : sa
      # transaction est annulée, elle reste programmée et repasse au prochain tour.
      def call
        now = @clock.now
        published = @messages.due_for_publication(now:).count { publish_safely(it, now) }
        Shared::Result.success(published)
      end

      private

      def publish_safely(due, now)
        publish(due, now)
      rescue StandardError => error
        Rails.error.report(error, handled: true, context: { message_id: due.id })
        false
      end

      # Les droits de l'auteur, revérifiés à l'heure de la parution : il a pu quitter l'école, perdre la classe, être anonymisé
      # ou le drapeau des enseignants être coupé depuis la programmation (B-007). Sinon l'annonce est archivée, pas publiée.
      def author_allowed?(message)
        actor = @users.actor_for(user_id: message.author_id, current_school_id: message.school_id)
        return false if actor.nil? || (actor.role == :teacher && !@teacher_flag.call)

        teachable = actor.role == :teacher ? @teachings.classroom_ids_for(teacher_id: actor.user_id, school_id: message.school_id) : []
        @policy.call(actor:, scope: (message.school_id ? "school" : "national"), school_id: message.school_id,
                     audience: message.audience, classroom_ids: message.classroom_ids,
                     teachable_classroom_ids: teachable).success?
      end

      # Le verrou de l'auteur d'abord, puis l'annonce relue (phase 5, F1) : archivée, reprogrammée ou déjà publiée par
      # son auteur depuis la lecture de la liste, elle n'est pas réécrite. Sa parution archive d'abord les plus anciennes
      # en ligne de son auteur (ADR-0081 §4.1). → true si elle est publiée
      def publish(due, now)
        @transaction.call do
          live = lock_author(due.author_id, now, due.cap_school_id)
          message = @messages.find_by_public_id(public_id: due.public_id)
          next false unless message.status == "scheduled" && message.published_at <= now

          unless author_allowed?(message)
            @messages.update(message: message.with(status: "archived"))
            Rails.logger.warn("[#{self.class.name}] scheduled message archived, author no longer allowed: message_id=#{message.id}")
            next false
          end

          make_room(live)
          # Le statut seul est écrit (phase 5, F2) : rien de ce qui a changé depuis la relecture n'est écrasé. Archivée,
          # retirée ou reprogrammée entre-temps : rien n'est écrit, ni archivé, ni journalisé.
          raise Frozen unless @messages.publish_scheduled(id: message.id, now:)

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
