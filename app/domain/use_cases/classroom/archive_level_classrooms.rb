# 🧠 DOMAINE · UseCases::Classroom::ArchiveLevelClassrooms
# Rôle : archive d'un coup les classes actives d'un niveau (toutes séries) d'un établissement pour l'année en cours, en une trace
# ADR  : 0028, 0059, 0071, 0088 · UDR : 0083
module UseCases
  module Classroom
    class ArchiveLevelClassrooms
      def initialize(classrooms:, schools:, audit_log:, policy:, transaction:, clock:)
        @classrooms = classrooms
        @schools = schools
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # Mêmes droits que pour une classe. → Result(Integer : classes archivées) | :not_found (établissement) | :forbidden
      #   | :conflict (errors: { base: [:nothing_to_archive] })
      def call(actor:, school_public_id:, level_id:)
        school = @schools.find_by_public_id(public_id: school_public_id)
        return Shared::Result.failure(:not_found) if school.nil?

        allowed = @policy.call(actor:, school:)
        return allowed if allowed.failure?

        @transaction.call do
          count = @classrooms.archive_level(school_id: school.id, level_id:, at: @clock.now,
                                            school_year: Entities::Classroom::SchoolYear.current(@clock.now.to_date))
          next Shared::Result.failure(:conflict, errors: { base: [ :nothing_to_archive ] }) if count.zero?

          record(actor, school, level_id, count)
        end
      end

      private

      def record(actor, school, level_id, count)
        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "School",
                          subject_id: school.id, metadata: { change: "level_archived", level_id:, classrooms_count: count })
        Shared::Result.success(count)
      end
    end
  end
end
