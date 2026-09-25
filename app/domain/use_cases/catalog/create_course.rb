# 🧠 DOMAINE · UseCases::Catalog::CreateCourse
# Rôle : l'équipe crée un cours en brouillon, dont elle est l'autrice ; la série doit être ouverte au niveau
# ADR  : 0026, 0028, 0035, 0037
module UseCases
  module Catalog
    class CreateCourse
      def initialize(courses:, taxonomy:, policy:)
        @courses = courses
        @taxonomy = taxonomy
        @policy = policy
      end

      # Faits du référentiel d'un cours saisi, partagés avec UpdateCourse.
      # → Result({ level_id:, series_id:, material_id: }) | failure(:invalid, errors: { <champ>_slug: [:inclusion | :not_allowed] })
      def self.taxonomy_ids(dto:, lookup:)
        level = lookup.level(dto.level_slug)
        material = lookup.materials.find { |item| item.slug == dto.material_slug }
        series = lookup.find_series(dto.series_slug)
        errors = { level_slug: (:inclusion if level.nil?), material_slug: (:inclusion if material.nil?),
                   series_slug: series_error(dto.series_slug, series, level, lookup) }.compact.transform_values { [ it ] }
        return Shared::Result.failure(:invalid, errors:) if errors.any?

        Shared::Result.success({ level_id: level.id, series_id: series&.id, material_id: material.id })
      end

      # Une série est facultative ; donnée, elle doit exister et être ouverte au niveau, s'il est connu.
      def self.series_error(slug, series, level, lookup)
        return if slug.nil?
        return :inclusion if series.nil?

        :not_allowed if level && !lookup.pair?(level.id, series.id)
      end
      private_class_method :series_error

      # dto : Dtos::Catalog::CourseInput. → Result(Course) | :forbidden | :invalid | :conflict (name taken)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        taxonomy = self.class.taxonomy_ids(dto:, lookup: @taxonomy.lookup)
        return taxonomy if taxonomy.failure?

        @courses.create(course: Entities::Catalog::Course.new(
          name: dto.name, subtitle: dto.subtitle, content: dto.content, status: "draft", author_id: actor.user_id, **taxonomy.value
        ))
      end
    end
  end
end
