# 🔌 INFRA · Repositories::Catalog::TaxonomyRepository
# Rôle : référentiel géré par l'équipe (niveaux, séries, liaisons, matières) et son index en mémoire pour les imports
# ADR  : 0029, 0034, 0036, 0058
module Repositories
  module Catalog
    class TaxonomyRepository
      include Ports::Catalog::TaxonomyRepositoryPort

      def levels
        Orm::Level.order(:position).map { |record| map_level(record) }
      end

      def series
        Orm::Series.order(:name).map { |record| map_series(record) }
      end

      def materials
        Orm::Material.order(:name).map { |record| map_material(record) }
      end

      def find_level(slug:)
        record = Orm::Level.find_by(slug:)
        record && map_level(record)
      end

      def find_series(slug:)
        record = Orm::Series.find_by(slug:)
        record && map_series(record)
      end

      def find_material(slug:)
        record = Orm::Material.find_by(slug:)
        record && map_material(record)
      end

      def create_level(level:)
        persist(Orm::Level.new, level_attributes(level), :map_level)
      end

      def update_level(level:)
        persist(Orm::Level.find(level.id), level_attributes(level), :map_level)
      end

      def delete_level(id:)
        delete(Orm::Level, id, Orm::Classroom.exists?(level_id: id) || Orm::Course.exists?(level_id: id) ||
                               Orm::LevelSeries.exists?(level_id: id), plan_entries: { level_id: id })
      end

      def create_series(series:)
        persist(Orm::Series.new, { name: series.name }, :map_series)
      end

      def update_series(series:)
        persist(Orm::Series.find(series.id), { name: series.name }, :map_series)
      end

      def delete_series(id:)
        delete(Orm::Series, id, Orm::Classroom.exists?(series_id: id) || Orm::Course.exists?(series_id: id) ||
                                Orm::LevelSeries.exists?(series_id: id), plan_entries: { series_id: id })
      end

      def create_material(material:)
        persist(Orm::Material.new, material_attributes(material), :map_material)
      end

      def update_material(material:)
        persist(Orm::Material.find(material.id), material_attributes(material), :map_material)
      end

      def delete_material(id:)
        delete(Orm::Material, id, Orm::Course.exists?(material_id: id) || Orm::TeacherProfile.exists?(material_id: id))
      end

      def link(level_id:, series_id:, at:)
        # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
        Orm::LevelSeries.transaction(requires_new: true) { Orm::LevelSeries.create!(level_id:, series_id:, created_at: at) }
        ::Shared::Result.success
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { base: [ :already_linked ] })
      end

      # Refusé tant qu'une classe ou un cours porte le couple.
      def unlink(level_id:, series_id:)
        referenced = Orm::Classroom.exists?(level_id:, series_id:) || Orm::Course.exists?(level_id:, series_id:)
        delete(Orm::LevelSeries.where(level_id:, series_id:), nil, referenced)
      end

      def lookup
        Entities::Catalog::TaxonomyLookup.new(levels:, series:, materials:,
                                              pairs: Orm::LevelSeries.pluck(:level_id, :series_id))
      end

      private

      def level_attributes(level) = { name: level.name, position: level.position, cycle: level.cycle }
      def material_attributes(material) = { name: material.name, shortname: material.shortname, category: material.category }

      # Le savepoint garde intacte la transaction du use case ; le champ fautif vient du nom de l'index refusé.
      def persist(record, attributes, mapper)
        record.assign_attributes(attributes)
        # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
        record.class.transaction(requires_new: true) { record.save! }
        ::Shared::Result.success(send(mapper, record))
      rescue ActiveRecord::RecordNotUnique => error
        field = attributes.keys.find { |key| error.message.include?("_on_#{key}\"") } || :name
        ::Shared::Result.failure(:conflict, errors: { field => [ :taken ] })
      end

      # scope : un modèle et un id, ou une relation déjà filtrée (id nil). plan_entries : les lignes du barème qui
      # partent avec un niveau ou une série supprimé (ADR-0058) ; elles ne retiennent jamais la suppression.
      def delete(scope, id, referenced, plan_entries: nil)
        return ::Shared::Result.failure(:conflict, errors: { base: [ :referenced ] }) if referenced

        Orm::ClassroomPlanEntry.where(plan_entries).delete_all if plan_entries
        (id ? scope.where(id:) : scope).delete_all
        ::Shared::Result.success
      end

      def map_level(record)
        Entities::Catalog::Level.new(id: record.id, slug: record.slug, name: record.name, position: record.position,
                                     cycle: record.cycle)
      end

      def map_series(record) = Entities::Catalog::Series.new(id: record.id, slug: record.slug, name: record.name)

      def map_material(record)
        Entities::Catalog::Material.new(id: record.id, slug: record.slug, name: record.name, shortname: record.shortname,
                                        category: record.category)
      end
    end
  end
end
