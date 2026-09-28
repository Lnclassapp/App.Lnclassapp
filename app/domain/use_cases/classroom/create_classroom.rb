# 🧠 DOMAINE · UseCases::Classroom::CreateClassroom
# Rôle : l'équipe ajoute une classe à un établissement pour l'année scolaire en cours ; le repository tire son code
# ADR  : 0026, 0028, 0030, 0041, 0059 · UDR : 0031
module UseCases
  module Classroom
    class CreateClassroom
      def initialize(classrooms:, schools:, taxonomy:, policy:, clock:)
        @classrooms = classrooms
        @schools = schools
        @taxonomy = taxonomy
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Classroom::ClassroomInput.
      # → Result(Classroom) | :forbidden | :invalid | :not_found (établissement)
      #   | :conflict (établissement désactivé ou en brouillon, nom pris)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        school = @schools.find_by_public_id(public_id: dto.school_public_id)
        return Shared::Result.failure(:not_found) if school.nil?
        return Shared::Result.failure(:conflict, errors: { base: [ :school_inactive ] }) if school.status == "inactive"
        # Décision du porteur (2026-09-27) : un établissement en brouillon est activé avant de recevoir une classe.
        return Shared::Result.failure(:conflict, errors: { base: [ :school_draft ] }) if school.status == "draft"

        placement = Entities::Classroom::Placement.resolve(school:, level_slug: dto.level_slug, series_slug: dto.series_slug,
                                                           lookup: @taxonomy.lookup)
        return placement if placement.failure?

        @classrooms.create(classroom: Entities::Classroom::Classroom.new(
          school_id: school.id, school_year: Entities::Classroom::SchoolYear.current(@clock.now.to_date), status: "active",
          **placement.value.ids, **dto.to_h
        ))
      end
    end
  end
end
