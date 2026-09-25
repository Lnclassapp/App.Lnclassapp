# 🧠 DOMAINE · UseCases::School::DeactivateSchool
# Rôle : passe un établissement au statut inactive : il sort de l'inscription enseignant et de la création de classe, rien n'est supprimé
# ADR  : 0026, 0028, 0036, 0050 · UDR : 0036
module UseCases
  module School
    class DeactivateSchool
      INACTIVE = "inactive".freeze

      def initialize(schools:, audit_log:, policy:, transaction:, clock:)
        @schools = schools
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # → Result(School) | :forbidden | :not_found ; une école déjà inactive est rendue telle quelle, sans écriture.
      def call(actor:, public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        school = @schools.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if school.nil?
        return Shared::Result.success(school) if school.status == INACTIVE

        school.status = INACTIVE
        @transaction.call do
          updated = @schools.update(school:)
          record(actor, updated.value) if updated.success?
          updated
        end
      end

      private

      def record(actor, school)
        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "School",
                          subject_id: school.id, metadata: { change: "deactivated", public_id: school.public_id })
      end
    end
  end
end
