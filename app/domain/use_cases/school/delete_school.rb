# 🧠 DOMAINE · UseCases::School::DeleteSchool
# Rôle : supprime un établissement et ses classes si aucune n'a d'élève, d'enseignant ni d'assignation ; sinon refus
# ADR  : 0026, 0028, 0036, 0050 · UDR : 0036
module UseCases
  module School
    class DeleteSchool
      def initialize(schools:, audit_log:, policy:, transaction:, clock:)
        @schools = schools
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # → Result | :forbidden | :not_found | :conflict (errors: { base: [:referenced] }) : l'équipe désactive plutôt
      def call(actor:, public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        school = @schools.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if school.nil?

        @transaction.call do
          deleted = @schools.delete_if_unreferenced(id: school.id)
          record(actor, school) if deleted.success?
          deleted
        end
      end

      private

      def record(actor, school)
        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "School",
                          subject_id: school.id, metadata: { change: "deleted", public_id: school.public_id, name: school.name })
      end
    end
  end
end
