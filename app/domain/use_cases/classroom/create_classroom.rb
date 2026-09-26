# 🧠 DOMAINE · UseCases::Classroom::CreateClassroom
# Rôle : l'équipe ajoute une classe à un établissement pour l'année scolaire en cours ; le repository tire son code
# ADR  : 0026, 0028, 0030, 0041 · UDR : 0031
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
      # → Result(Classroom) | :forbidden | :invalid | :not_found (établissement) | :conflict (établissement désactivé, nom pris)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        school = @schools.find_by_public_id(public_id: dto.school_public_id)
        return Shared::Result.failure(:not_found) if school.nil?
        return Shared::Result.failure(:conflict, errors: { base: [ :school_inactive ] }) if school.status == "inactive"

        taxonomy = taxonomy_ids(dto, school, @taxonomy.lookup)
        return taxonomy if taxonomy.failure?

        @classrooms.create(classroom: Entities::Classroom::Classroom.new(
          school_id: school.id, school_year: Entities::Classroom::SchoolYear.current(@clock.now.to_date), status: "active",
          **taxonomy.value, **dto.to_h
        ))
      end

      private

      # Comme la génération (DefaultClassroomPlan) : un collège n'a que le premier cycle, et une classe d'un niveau à
      # séries en porte une, ouverte à ce niveau. → Result({ level_id:, series_id: }) | failure(:invalid, errors:)
      def taxonomy_ids(dto, school, lookup)
        level = lookup.level(dto.level_slug)
        return invalid(:level_slug, :inclusion) if level.nil?
        return invalid(:level_slug, :not_allowed) if school.cycle == "first" && !level.first_cycle?

        series = lookup.find_series(dto.series_slug)
        error = series_error(dto.series_slug, series, level, lookup)
        return invalid(:series_slug, error) if error

        Shared::Result.success({ level_id: level.id, series_id: series_id(series) })
      end

      def series_error(slug, series, level, lookup)
        return missing_series(level, lookup) if slug.nil?
        return :inclusion if series.nil?

        :not_allowed unless lookup.pair?(level.id, series.id)
      end

      def missing_series(level, lookup)
        :blank if lookup.series_for(level.id).any?
      end

      def series_id(series)
        series.id if series
      end

      def invalid(field, kind) = Shared::Result.failure(:invalid, errors: { field => [ kind ] })
    end
  end
end
