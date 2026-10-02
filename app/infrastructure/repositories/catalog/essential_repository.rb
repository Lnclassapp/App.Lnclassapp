# 🔌 INFRA · Repositories::Catalog::EssentialRepository
# Rôle : traduit Orm::Essential et son contenu riche (Action Text) ↔ Entities::Catalog::Essential, avec le statut du cours
# ADR  : 0029, 0035, 0039
module Repositories
  module Catalog
    class EssentialRepository
      include Ports::Catalog::EssentialRepositoryPort

      def find_by_slug(slug:)
        # A single record: no eager loading, which Bullet reports as unused (lot B2). Rich text and course cost one query each.
        record = Orm::Essential.find_by(slug:)
        record && map_to_entity(record)
      end

      def create(essential:)
        persist(Orm::Essential.new(slug: essential.slug, course_id: essential.course_id, author_id: essential.author_id,
                                   position: essential.position || next_position(course_id: essential.course_id),
                                   status: essential.status || "draft", **editable_attributes(essential)))
      end

      def update(essential:)
        record = Orm::Essential.find(essential.id)
        record.assign_attributes(editable_attributes(essential))
        persist(record)
      end

      # La première publication pose published_at ; l'archivage pose archived_at (ADR-0035).
      def transition(id:, to:, at:)
        scope = Orm::Essential.where(id:)
        case to
        when "published"
          scope.update_all([ "status = 'published', published_at = COALESCE(published_at, ?), archived_at = NULL, updated_at = ?", at, at ])
        when "archived" then scope.update_all(status: "archived", archived_at: at, updated_at: at)
        else raise ArgumentError, "transition impossible vers #{to.inspect}"
        end
        true
      end

      def existing_keys(course_ids: nil)
        scope = course_ids.nil? ? Orm::Essential.all : Orm::Essential.where(course_id: course_ids)
        scope.pluck(:course_id, :name).to_set { |course_id, name| [ course_id, Entities::Shared::NaturalKey.normalize(name) ] }
      end

      def next_position(course_id:)
        Orm::Essential.where(course_id:).maximum(:position).to_i + 1
      end

      def draft_slugs(course_id:)
        Orm::Essential.where(course_id:, status: "draft").order(:position, :id).pluck(:slug)
      end

      def taken_slugs
        Orm::Essential.pluck(:slug).to_set
      end

      private

      def editable_attributes(essential)
        { name: essential.name, subtitle: essential.subtitle, content: RichTextSanitizer.call(essential.content) }
      end

      # Savepoint : traduit seulement une violation d'index unique, sans casser la transaction du use case.
      def persist(record)
        Orm::Essential.transaction(requires_new: true) { record.save! }
        ::Shared::Result.success(map_to_entity(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { name: [ :taken ] })
      end

      # Le HTML du contenu riche, assaini à l'écriture (RichTextSanitizer) puis de nouveau au rendu par Action Text.
      def map_to_entity(record)
        Entities::Catalog::Essential.new(
          id: record.id, slug: record.slug, course_id: record.course_id, name: record.name, subtitle: record.subtitle,
          position: record.position, author_id: record.author_id, status: record.status,
          published_at: record.published_at, archived_at: record.archived_at, content: record.content.body&.to_html,
          course_status: record.course.status
        )
      end
    end
  end
end
