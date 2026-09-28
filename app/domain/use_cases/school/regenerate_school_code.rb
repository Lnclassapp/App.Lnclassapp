# 🧠 DOMAINE · UseCases::School::RegenerateSchoolCode
# Rôle : remplace le code d'établissement ; l'ancien cesse aussitôt de fonctionner, les enseignants inscrits restent rattachés
# ADR  : 0026, 0028, 0057 · UDR : 0044
module UseCases
  module School
    class RegenerateSchoolCode
      # Un code tiré qui existe déjà est refusé par l'index unique : on en retire un autre, cinq fois au plus.
      ATTEMPTS = 5

      def initialize(schools:, audit_log:, policy:, transaction:, clock:)
        @schools = schools
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # → Result(School) | :forbidden | :not_found | :conflict (aucun code libre après ATTEMPTS tirages)
      def call(actor:, public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        school = @schools.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if school.nil?

        now = @clock.now
        @transaction.call do
          replaced = replace(school, now)
          record(actor, replaced.value, now) if replaced.success?
          replaced
        end
      end

      private

      def replace(school, now)
        replaced = nil
        ATTEMPTS.times do
          replaced = @schools.replace_school_code(id: school.id, school_code: Entities::School::SchoolCode.generate, at: now)
          break if replaced.success?
        end
        replaced
      end

      def record(actor, school, now)
        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: now, subject_type: "School",
                          subject_id: school.id, metadata: { change: "code_regenerated", public_id: school.public_id })
      end
    end
  end
end
