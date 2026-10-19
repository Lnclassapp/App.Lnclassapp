# 🧠 DOMAINE · UseCases::Classroom::UpdateClassroom
# Rôle : « Modifier la classe » : suffixe du nom après le préfixe fixe du barème, plafond jamais sous l'effectif ; tracé
# ADR  : 0041, 0059, 0088, 0098 · UDR : 0110, 0111
module UseCases
  module Classroom
    class UpdateClassroom
      NAME_MAX = Entities::Classroom::Classroom::NAME_MAX
      NUMBERING = Entities::Classroom::ClassroomNumbering

      def initialize(classrooms:, schools:, taxonomy:, audit_log:, policy:, transaction:, clock:)
        @classrooms = classrooms
        @schools = schools
        @taxonomy = taxonomy
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # dto : Dtos::Classroom::ClassroomSettingsInput. Tout statut d'établissement pour l'équipe ; la direction, son seul
      # établissement actif (ManageSchoolStructurePolicy, appelée une fois l'établissement lu). Rien de changé : succès sans trace.
      # → Result(Classroom) | :not_found (établissement, classe hors de lui ou de l'année) | :forbidden
      #   | :invalid (suffix: [:blank | :too_long], max_students) | :conflict (base: [:archived], max_students: [:below_headcount], suffix: [:taken])
      def call(actor:, school_public_id:, classroom_public_id:, dto:)
        school = @schools.find_by_public_id(public_id: school_public_id)
        return Shared::Result.failure(:not_found) if school.nil?

        allowed = @policy.call(actor:, school:)
        return allowed if allowed.failure?

        classroom = @classrooms.find_by_public_id(public_id: classroom_public_id)
        return Shared::Result.failure(:not_found) unless in_current_year?(classroom, school)
        return Shared::Result.failure(:conflict, errors: { base: [ :archived ] }) if classroom.archived?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        name = NUMBERING.full_name(prefix: prefix_of(classroom), suffix: dto.suffix)
        return Shared::Result.failure(:invalid, errors: { suffix: [ :too_long ] }) if name.length > NAME_MAX
        return Shared::Result.success(classroom) if [ name, dto.max_students ] == [ classroom.name, classroom.max_students ]

        @transaction.call do
          changed = @classrooms.update_settings(id: classroom.id, name:, max_students: dto.max_students)
          changed.success? ? record(actor, school, classroom, changed.value) : changed
        end
      end

      private

      def in_current_year?(classroom, school)
        classroom.present? && classroom.school_id == school.id &&
          classroom.school_year == Entities::Classroom::SchoolYear.current(@clock.now.to_date)
      end

      # Une classe a toujours son niveau ; sa série, seulement aux niveaux qui en ont (clés étrangères).
      def prefix_of(classroom)
        lookup = @taxonomy.lookup
        level = lookup.levels.find { it.id == classroom.level_id }
        series = lookup.series.find { it.id == classroom.series_id }
        NUMBERING.prefix(level_name: level.name, series_name: series&.name)
      end

      def record(actor, school, before, after)
        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "School",
                          subject_id: school.id,
                          metadata: { change: "classroom_updated", classroom_public_id: after.public_id, name: after.name,
                                      previous_name: before.name, max_students: after.max_students,
                                      previous_max_students: before.max_students })
        Shared::Result.success(after)
      end
    end
  end
end
