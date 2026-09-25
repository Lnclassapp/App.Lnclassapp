# 🧠 DOMAINE · UseCases::Catalog::UpdateCourse
# Rôle : l'équipe modifie un cours, quel que soit son statut ; slug, statut, auteur et dates ne changent pas
# ADR  : 0026, 0028, 0029, 0035, 0037
module UseCases
  module Catalog
    class UpdateCourse
      def initialize(courses:, taxonomy:, policy:)
        @courses = courses
        @taxonomy = taxonomy
        @policy = policy
      end

      # dto : Dtos::Catalog::CourseInput. → Result(Course) | :forbidden | :not_found | :invalid | :conflict (name taken)
      def call(actor:, slug:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        current = @courses.find_by_slug(slug:)
        return Shared::Result.failure(:not_found) if current.nil?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        taxonomy = CreateCourse.taxonomy_ids(dto:, lookup: @taxonomy.lookup)
        return taxonomy if taxonomy.failure?

        own = CreateCourse.course_key(current.name, { level_id: current.level_id, material_id: current.material_id, series_id: current.series_id })
        return CreateCourse.name_taken if CreateCourse.name_taken?(@courses, CreateCourse.course_key(dto.name, taxonomy.value), except: own)

        @courses.update(course: Entities::Catalog::Course.new(
          id: current.id, slug: current.slug, status: current.status, author_id: current.author_id,
          published_at: current.published_at, archived_at: current.archived_at,
          name: dto.name, subtitle: dto.subtitle, content: dto.content, **taxonomy.value
        ))
      end
    end
  end
end
