# 🧠 DOMAINE · UseCases::Classroom::AddLevelClassroom
# Rôle : « + » du bloc « Classes par niveau » : crée la classe suivante d'un niveau/série, nommée comme au barème, et la trace
# ADR  : 0028, 0030, 0041, 0059 · UDR : 0046
module UseCases
  module Classroom
    class AddLevelClassroom
      # Deux « + » simultanés tombent sur le même nom : l'index unique refuse le second, qui recalcule une fois.
      ATTEMPTS = 2

      def initialize(classrooms:, schools:, taxonomy:, audit_log:, policy:, transaction:, clock:)
        @classrooms = classrooms
        @schools = schools
        @taxonomy = taxonomy
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # series_slug nil pour un niveau sans série.
      # → Result(Classroom) | :forbidden | :not_found | :invalid (niveau, série, nom trop long)
      #   | :conflict (errors: { base: [:school_inactive | :school_draft | :name_taken] })
      def call(actor:, school_public_id:, level_slug:, series_slug:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        school = @schools.find_by_public_id(public_id: school_public_id)
        return Shared::Result.failure(:not_found) if school.nil?
        return conflict(:school_inactive) if school.status == "inactive"
        # Comme « Ajouter une classe » (décision du porteur, 2026-09-27) : un brouillon est activé d'abord.
        return conflict(:school_draft) if school.status == "draft"

        placement = Entities::Classroom::Placement.resolve(school:, level_slug: level_slug.to_s.strip.presence,
                                                           series_slug: series_slug.to_s.strip.presence, lookup: @taxonomy.lookup)
        return placement if placement.failure?

        @transaction.call { create(actor, school, placement.value) }
      end

      private

      def create(actor, school, placement, attempts: ATTEMPTS)
        classroom = build(school, placement)
        return Shared::Result.failure(:invalid, errors: classroom.errors.to_hash) unless classroom.valid?

        created = @classrooms.create(classroom:)
        return record(actor, school, created) if created.success?
        return create(actor, school, placement, attempts: attempts - 1) if attempts > 1

        conflict(:name_taken)
      end

      def build(school, placement)
        school_year = Entities::Classroom::SchoolYear.current(@clock.now.to_date)
        prefix = Entities::Classroom::ClassroomNumbering.prefix(level_name: placement.level.name, series_name: placement.series&.name)
        name = Entities::Classroom::ClassroomNumbering.next_name(prefix:, taken: @classrooms.names_in(school_id: school.id, school_year:))
        Entities::Classroom::Classroom.new(school_id: school.id, school_year:, name:, status: "active", **placement.ids)
      end

      def record(actor, school, created)
        classroom = created.value
        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "School",
                          subject_id: school.id,
                          metadata: { change: "classroom_added", classroom_public_id: classroom.public_id, name: classroom.name })
        created
      end

      def conflict(reason) = Shared::Result.failure(:conflict, errors: { base: [ reason ] })
    end
  end
end
