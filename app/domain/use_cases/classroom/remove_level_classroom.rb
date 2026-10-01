# 🧠 DOMAINE · UseCases::Classroom::RemoveLevelClassroom
# Rôle : « − » du bloc « Classes par niveau » : supprime la dernière classe d'un niveau/série si elle n'a jamais servi, et la trace
# ADR  : 0028, 0036, 0041, 0059, 0071 · UDR : 0046, 0056
module UseCases
  module Classroom
    class RemoveLevelClassroom
      def initialize(classrooms:, schools:, audit_log:, policy:, transaction:, clock:)
        @classrooms = classrooms
        @schools = schools
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # classroom_public_id : la classe que la confirmation a nommée. Tout statut d'établissement pour l'équipe (ADR-0059) ;
      # la direction, son seul établissement actif (policy : ManageSchoolStructurePolicy, appelée une fois l'établissement lu).
      # → Result(Classroom supprimée) | :not_found (établissement, classe hors de lui ou de l'année) | :forbidden
      #   | :conflict (errors: { base: [:not_last | :has_students | :has_teachers | :has_assignments] })
      def call(actor:, school_public_id:, classroom_public_id:)
        school = @schools.find_by_public_id(public_id: school_public_id)
        return Shared::Result.failure(:not_found) if school.nil?

        allowed = @policy.call(actor:, school:)
        return allowed if allowed.failure?

        classroom = @classrooms.find_by_public_id(public_id: classroom_public_id)
        return Shared::Result.failure(:not_found) unless in_current_year?(classroom, school)
        return Shared::Result.failure(:conflict, errors: { base: [ :not_last ] }) unless last?(classroom)

        @transaction.call do
          deleted = @classrooms.delete_if_unused(id: classroom.id)
          deleted.success? ? record(actor, school, classroom) : deleted
        end
      end

      private

      def in_current_year?(classroom, school)
        classroom.present? && classroom.school_id == school.id &&
          classroom.school_year == Entities::Classroom::SchoolYear.current(@clock.now.to_date)
      end

      def last?(classroom)
        names = @classrooms.names_in_level(school_id: classroom.school_id, school_year: classroom.school_year,
                                           level_id: classroom.level_id, series_id: classroom.series_id)
        Entities::Classroom::ClassroomNumbering.last(names:) == classroom.name
      end

      def record(actor, school, classroom)
        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "School",
                          subject_id: school.id,
                          metadata: { change: "classroom_removed", classroom_public_id: classroom.public_id, name: classroom.name })
        Shared::Result.success(classroom)
      end
    end
  end
end
