# 🧠 DOMAINE · UseCases::Classroom::ArchiveClassroom
# Rôle : archive une classe de l'année en cours, quel que soit son contenu (élèves, enseignants, assignations restent), et la trace
# ADR  : 0028, 0059, 0071, 0088 · UDR : 0083
module UseCases
  module Classroom
    class ArchiveClassroom
      def initialize(classrooms:, schools:, audit_log:, policy:, transaction:, clock:)
        @classrooms = classrooms
        @schools = schools
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # Tout statut d'établissement pour l'équipe ; la direction, son seul établissement actif (policy : ManageSchoolStructurePolicy,
      # appelée une fois l'établissement lu). → Result(Classroom) | :not_found (établissement, classe hors de lui ou de l'année)
      #   | :forbidden | :conflict (errors: { base: [:already_archived] })
      def call(actor:, school_public_id:, classroom_public_id:)
        school = @schools.find_by_public_id(public_id: school_public_id)
        return Shared::Result.failure(:not_found) if school.nil?

        allowed = @policy.call(actor:, school:)
        return allowed if allowed.failure?

        classroom = @classrooms.find_by_public_id(public_id: classroom_public_id)
        return Shared::Result.failure(:not_found) unless in_current_year?(classroom, school)

        @transaction.call do
          changed = @classrooms.archive(id: classroom.id, at: @clock.now)
          changed.success? ? record(actor, school, changed.value) : changed
        end
      end

      private

      def in_current_year?(classroom, school)
        classroom.present? && classroom.school_id == school.id &&
          classroom.school_year == Entities::Classroom::SchoolYear.current(@clock.now.to_date)
      end

      def record(actor, school, classroom)
        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "School",
                          subject_id: school.id,
                          metadata: { change: "classroom_archived", classroom_public_id: classroom.public_id, name: classroom.name })
        Shared::Result.success(classroom)
      end
    end
  end
end
