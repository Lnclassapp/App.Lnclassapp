# 🔌 INFRA · Repositories::Communication::IllustrationRepository
# Rôle : bibliothèque d'illustrations de l'équipe : lecture, choix des auteurs, ajout sous verrou, renommage, retrait (jamais supprimée)
# ADR  : 0029, 0081
module Repositories
  module Communication
    class IllustrationRepository
      include Ports::Communication::IllustrationRepositoryPort

      def find_by_public_id(public_id:) = read(Orm::MessageIllustration.find_by(public_id:))

      def available = Orm::MessageIllustration.where(retired_at: nil).order(:created_at, :id).map { entity(it) }

      def find_all_by_ids(ids:) = Orm::MessageIllustration.where(id: ids).to_h { [ it.id, entity(it) ] }

      def create(illustration:)
        record = Orm::MessageIllustration.create!(
          public_id: illustration.public_id, name: illustration.name, view_box: illustration.view_box,
          shapes: illustration.shapes, created_by_id: illustration.created_by_id, retired_at: illustration.retired_at
        )
        entity(record)
      end

      def rename(id:, name:)
        Orm::MessageIllustration.where(id:).update_all(name:, updated_at: Time.current)
        read(Orm::MessageIllustration.find_by(id:))
      end

      # Seule une illustration encore offerte prend la date : un second retrait ne la déplace pas.
      def retire(id:, at:)
        Orm::MessageIllustration.where(id:, retired_at: nil).update_all(retired_at: at, updated_at: Time.current)
        read(Orm::MessageIllustration.find_by(id:))
      end

      # Un verrou consultatif de transaction (pg_advisory_xact_lock) : aucune ligne n'est verrouillée, les lectures
      # passent, et il tombe avec la transaction de l'appelant. Une seule bibliothèque, une seule clé.
      def lock_library
        Orm::MessageIllustration.connection.execute("SELECT pg_advisory_xact_lock(hashtext('message_illustrations'))")
        true
      end

      private

      def read(record) = record && entity(record)

      def entity(record)
        Entities::Communication::Illustration.new(
          id: record.id, public_id: record.public_id, name: record.name, view_box: record.view_box, shapes: record.shapes,
          created_by_id: record.created_by_id, retired_at: record.retired_at
        )
      end
    end
  end
end
