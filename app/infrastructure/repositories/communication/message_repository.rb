# 🔌 INFRA · Repositories::Communication::MessageRepository
# Rôle : annonces et leurs classes ciblées, écrites ensemble ; rejets effacés ; programmées venues, publiées par leur seul statut ; en ligne sous verrou
# ADR  : 0029, 0045, 0078, 0081
module Repositories
  module Communication
    class MessageRepository
      include Ports::Communication::MessageRepositoryPort

      # Ce qu'une écriture pose sur la ligne ; l'auteur et le public_id ne changent qu'à la création.
      WRITTEN = %i[title body audience school_id illustration status published_at ends_at edited_at withdrawn_at
                   withdrawn_by_id theme illustration_id].freeze

      def find_by_public_id(public_id:)
        record = Orm::Message.find_by(public_id:)
        record && entity(record, classroom_ids_of([ record.id ]).fetch(record.id, []))
      end

      def create(message:)
        Orm::Message.transaction do
          record = Orm::Message.create!(**message.to_h.slice(*WRITTEN), author_id: message.author_id, public_id: message.public_id)
          entity(record, target(record.id, message.classroom_ids))
        end
      end

      # La ligne est verrouillée puis relue : une écriture lue avant un archivage ou un retrait ne la rend pas vivante.
      def update(message:)
        Orm::Message.transaction do
          record = Orm::Message.lock.find(message.id)
          next if entity(record, []).frozen?

          record.update!(message.to_h.slice(*WRITTEN))
          Orm::MessageClassroom.where(message_id: record.id).delete_all
          entity(record, target(record.id, message.classroom_ids))
        end
      end

      def clear_dismissals(message_id:) = Orm::MessageDismissal.where(message_id:).delete_all

      # Deux requêtes, quel que soit le nombre d'annonces : les lignes, puis toutes leurs classes.
      def due_for_publication(now:)
        records = Orm::Message.where(status: "scheduled", published_at: ..now).order(:published_at, :id).to_a
        classroom_ids = classroom_ids_of(records.map(&:id))
        records.map { entity(it, classroom_ids.fetch(it.id, [])) }
      end

      def author_role(message:) = Orm::User.where(id: message.author_id).pick(:role).to_sym

      # ADR-0081 §4.1 : le verrou de la ligne users dure jusqu'à la fin de la transaction de l'appelant ; une seconde
      # parution du même auteur attend ici, puis lit ce que la première a écrit. Trois requêtes : verrou, lignes, classes.
      # FOR NO KEY UPDATE (phase 5) : il exclut une autre parution, mais pas une ligne qui référence l'auteur par clé
      # étrangère (journal d'audit…, FOR KEY SHARE), que FOR UPDATE bloquerait pendant tout le téléversement.
      def live_of(author_id:, now:)
        Orm::User.where(id: author_id).lock("FOR NO KEY UPDATE").pluck(:id)
        # published_at n'est pas comparé à now : une annonce publiée l'a été en s'écrivant, et une parution concurrente qui a
        # lu son horloge avant le verrou doit compter celle que l'autre vient de publier.
        records = Orm::Message.where(author_id:, status: "published").where("ends_at > ?", now)
                              .order(:published_at, :id).to_a
        classroom_ids = classroom_ids_of(records.map(&:id))
        records.map { entity(it, classroom_ids.fetch(it.id, [])) }
      end

      # Phase 5 (F2) : une seule écriture conditionnelle, qui verrouille la ligne ; le reste de la ligne est celui de la
      # base, jamais une copie lue avant. Deux requêtes : l'écriture, puis la relecture avec ses classes.
      def publish_scheduled(id:, now:)
        written = Orm::Message.where(id:, status: "scheduled", published_at: ..now)
                              .update_all(status: "published", updated_at: Time.current)
        return if written.zero?

        entity(Orm::Message.find(id), classroom_ids_of([ id ]).fetch(id, []))
      end

      private

      # Écrit les classes ciblées, une fois chacune. → leurs ids triés
      def target(message_id, classroom_ids)
        ids = classroom_ids.uniq.sort
        Orm::MessageClassroom.insert_all!(ids.map { { message_id:, classroom_id: it } }) if ids.any?
        ids
      end

      # → { message_id => [classroom_id triés] }
      def classroom_ids_of(message_ids)
        Orm::MessageClassroom.where(message_id: message_ids).order(:classroom_id).pluck(:message_id, :classroom_id)
                             .group_by(&:first).transform_values { it.map(&:last) }
      end

      def entity(record, classroom_ids)
        Entities::Communication::Message.new(
          id: record.id, public_id: record.public_id, author_id: record.author_id, title: record.title, body: record.body,
          audience: record.audience, school_id: record.school_id, classroom_ids:, illustration: record.illustration,
          status: record.status, published_at: record.published_at, ends_at: record.ends_at, edited_at: record.edited_at,
          withdrawn_at: record.withdrawn_at, withdrawn_by_id: record.withdrawn_by_id, theme: record.theme,
          illustration_id: record.illustration_id
        )
      end
    end
  end
end
