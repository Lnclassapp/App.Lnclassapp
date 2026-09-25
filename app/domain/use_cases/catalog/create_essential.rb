# 🧠 DOMAINE · UseCases::Catalog::CreateEssential
# Rôle : l'équipe crée une fiche essentielle en brouillon, à la suite des fiches de son cours ; nom unique dans le cours
# ADR  : 0026, 0028, 0035
module UseCases
  module Catalog
    class CreateEssential
      def initialize(courses:, essentials:, transaction:, policy:)
        @courses = courses
        @essentials = essentials
        @transaction = transaction
        @policy = policy
      end

      # dto : Dtos::Catalog::EssentialInput. → Result(Essential) | :forbidden | :not_found | :invalid | :conflict (nom pris)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        course = @courses.find_by_slug(slug: dto.course_slug)
        return Shared::Result.failure(:not_found) if course.nil?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        essential = Entities::Catalog::Essential.new(course_id: course.id, course_status: course.status, status: "draft",
                                                     author_id: actor.user_id, **dto.essential_attributes)
        @transaction.call do
          essential.position = @essentials.next_position(course_id: course.id)
          @essentials.create(essential:)
        end
      end
    end
  end
end
