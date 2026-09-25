# 🔌 INFRA · Repositories::Catalog::CourseRepository
# Rôle : traduit Orm::Course et son contenu riche (Action Text) ↔ Entities::Catalog::Course ; slug figé à la création
# ADR  : 0029, 0035, 0039
module Repositories
  module Catalog
    class CourseRepository
      include Ports::Catalog::CourseRepositoryPort

      def find_by_slug(slug:)
        # A single record: no eager loading, which Bullet reports as unused (lot B2). The rich text costs one query.
        record = Orm::Course.find_by(slug:)
        record && map_to_entity(record)
      end

      def create(course:)
        persist(Orm::Course.new(slug: course.slug, level_id: course.level_id, series_id: course.series_id,
                                material_id: course.material_id, author_id: course.author_id,
                                status: course.status || "draft", **editable_attributes(course)))
      end

      def update(course:)
        record = Orm::Course.find(course.id)
        record.assign_attributes(level_id: course.level_id, series_id: course.series_id, material_id: course.material_id,
                                 **editable_attributes(course))
        persist(record)
      end

      # La première publication pose published_at ; l'archivage pose archived_at (ADR-0035).
      def transition(id:, to:, at:)
        scope = Orm::Course.where(id:)
        case to
        when "published"
          scope.update_all([ "status = 'published', published_at = COALESCE(published_at, ?), archived_at = NULL, updated_at = ?", at, at ])
        when "archived" then scope.update_all(status: "archived", archived_at: at, updated_at: at)
        else raise ArgumentError, "transition impossible vers #{to.inspect}"
        end
        true
      end

      def existing_keys
        Orm::Course.pluck(:name, :level_id, :material_id, :series_id).to_set do |name, *taxonomy|
          [ Entities::Shared::NaturalKey.normalize(name), *taxonomy ]
        end
      end

      def taken_slugs
        Orm::Course.pluck(:slug).to_set
      end

      private

      def editable_attributes(course)
        { name: course.name, subtitle: course.subtitle, content: RichTextSanitizer.call(course.content) }
      end

      # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
      def persist(record)
        Orm::Course.transaction(requires_new: true) { record.save! }
        ::Shared::Result.success(map_to_entity(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { name: [ :taken ] })
      end

      # Le HTML du contenu riche, assaini à l'écriture (RichTextSanitizer) puis de nouveau au rendu par Action Text.
      def map_to_entity(record)
        Entities::Catalog::Course.new(
          id: record.id, slug: record.slug, name: record.name, subtitle: record.subtitle, level_id: record.level_id,
          series_id: record.series_id, material_id: record.material_id, author_id: record.author_id,
          status: record.status, published_at: record.published_at, archived_at: record.archived_at,
          content: record.content.body&.to_html
        )
      end
    end
  end
end
