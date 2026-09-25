# 🔌 INFRA · Repositories::School::DrenaRepository
# Rôle : traduit Orm::Drena ↔ Entities::School::Drena ; slug figé à la création, cible des imports d'écoles
# ADR  : 0029, 0034, 0036
module Repositories
  module School
    class DrenaRepository
      include Ports::School::DrenaRepositoryPort

      def all
        Orm::Drena.order(:name).map { |record| map_to_entity(record) }
      end

      def find_by_public_id(public_id:)
        find_by(public_id:)
      end

      def find_by_slug(slug:)
        find_by(slug:)
      end

      def create(drena:)
        persist(Orm::Drena.new(name: drena.name))
      end

      def update(drena:)
        record = Orm::Drena.find(drena.id)
        record.name = drena.name
        persist(record)
      end

      def delete(id:)
        if Orm::School.exists?(drena_id: id)
          return ::Shared::Result.failure(:conflict, errors: { base: [ :has_schools ] })
        end

        Orm::Drena.where(id:).delete_all
        ::Shared::Result.success
      end

      def ids_by_slug
        Orm::Drena.pluck(:slug, :id).to_h
      end

      private

      def find_by(**conditions)
        record = Orm::Drena.find_by(conditions)
        record && map_to_entity(record)
      end

      # Le savepoint garde intacte la transaction du use case quand l'index unique refuse la ligne.
      def persist(record)
        Orm::Drena.transaction(requires_new: true) { record.save! }
        ::Shared::Result.success(map_to_entity(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { name: [ :taken ] })
      end

      def map_to_entity(record)
        Entities::School::Drena.new(id: record.id, public_id: record.public_id, slug: record.slug, name: record.name)
      end
    end
  end
end
