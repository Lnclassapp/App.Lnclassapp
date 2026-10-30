# 🔌 INFRA · Repositories::Catalog::EssentialRepository
# Rôle : traduit Orm::Essential ↔ Entities::Catalog::Essential, avec le statut du cours ; transitions et clés de l'import
# ADR  : 0029, 0035, 0039, 0116, 0119-entrainement-de-notion-corrige-sans-trace
module Repositories
  module Catalog
    class EssentialRepository
      include Ports::Catalog::EssentialRepositoryPort

      # La notion lue pour être jugée : ce que ReadPublishedPolicy et ReadOwnLevelPolicy demandent, et son entraînement avec corrigé.
      PracticeNotion = Data.define(:slug, :name, :status, :course_status, :level_id, :series_id, :practice) do
        def readable_chain_published? = status == "published" && course_status == "published"
      end

      def find_by_slug(slug:)
        # A single record: no eager loading, which Bullet reports as unused (lot B2). The course costs one query.
        record = Orm::Essential.find_by(slug:)
        record && map_to_entity(record)
      end

      # La ligne est verrouillée avant d'être lue : le statut que voit le use case est celui qui sera écrit (menace.md, n° 15).
      def lock(id:)
        Orm::Essential.lock.find(id)
        true
      end

      def practice_for(course_slug:, notion_slug:, statuses:)
        row = Orm::Essential.joins(:course).where(slug: notion_slug, status: statuses, courses: { slug: course_slug })
                            .pick("essentials.slug", "essentials.name", "essentials.status", "courses.status", "courses.level_id",
                                  "courses.series_id", "essentials.sheet")
        return if row.nil?

        slug, name, status, course_status, level_id, series_id, sheet = row
        practice = Entities::Catalog::NotionPractice.from_raw(sheet.is_a?(Hash) ? sheet["practice"] : nil)
        PracticeNotion.new(slug:, name:, status:, course_status:, level_id:, series_id:, practice:) if practice
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

      def ids_by_name(course_id:)
        Orm::Essential.where(course_id:).pluck(:name, :id).to_h { |name, id| [ Entities::Shared::NaturalKey.normalize(name), id ] }
      end

      def names(course_id:)
        Orm::Essential.where(course_id:).order(:position, :id).pluck(:name)
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

      def map_to_entity(record)
        Entities::Catalog::Essential.new(
          id: record.id, slug: record.slug, course_id: record.course_id, name: record.name, subtitle: record.subtitle,
          position: record.position, author_id: record.author_id, status: record.status,
          published_at: record.published_at, archived_at: record.archived_at, course_status: record.course.status
        )
      end
    end
  end
end
