# 🔌 INFRA · Repositories::School::DrenaRepository
# Rôle : traduit Orm::Drena ↔ Entities::School::Drena ; slug figé à la création, cible des imports d'écoles ; écriture en masse de l'import
# ADR  : 0029, 0034, 0036, 0066
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

      def taken_names
        Orm::Drena.pluck(:name).to_set
      end

      # Pas de rappel ORM : slug et public_id arrivent calculés. Une violation d'unicité lève, et le moteur annule le lot.
      def insert_many(rows:, at:)
        return 0 if rows.empty?

        Orm::Drena.insert_all!(rows.map { |row| row.merge(created_at: at, updated_at: at) }).length
      end

      private

      def find_by(**conditions)
        record = Orm::Drena.find_by(conditions)
        record && map_to_entity(record)
      end

      # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
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
