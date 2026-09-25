# 🧠 DOMAINE · UseCases::School::DeleteDrena
# Rôle : l'équipe supprime une DRENA sans établissement ; avec des établissements, refus avec la raison, aucune cascade
# ADR  : 0026, 0028, 0036
module UseCases
  module School
    class DeleteDrena
      def initialize(drenas:, audit_log:, transaction:, policy:, clock:)
        @drenas = drenas
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result(Entities::School::Drena supprimée) | :forbidden | :not_found | :conflict (errors: { base: [:has_schools] })
      def call(actor:, public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        drena = @drenas.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if drena.nil?

        @transaction.call { remove(actor, drena) }
      end

      private

      def remove(actor, drena)
        deleted = @drenas.delete(id: drena.id)
        return deleted if deleted.failure?

        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "Drena",
                          subject_id: drena.id, metadata: { change: "drena.deleted", name: drena.name })
        Shared::Result.success(drena)
      end
    end
  end
end
