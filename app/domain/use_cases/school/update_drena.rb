# 🧠 DOMAINE · UseCases::School::UpdateDrena
# Rôle : l'équipe renomme une DRENA ; le slug ne change jamais, les fichiers d'import qui le citent restent valides
# ADR  : 0026, 0028, 0029, 0034
module UseCases
  module School
    class UpdateDrena
      def initialize(drenas:, audit_log:, transaction:, policy:, clock:)
        @drenas = drenas
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::School::DrenaInput. → Result(Entities::School::Drena) | :forbidden | :not_found | :invalid | :conflict
      def call(actor:, public_id:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        drena = @drenas.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if drena.nil?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        previous_name = drena.name
        drena.name = dto.name
        @transaction.call { store(actor, drena, previous_name) }
      end

      private

      def store(actor, drena, previous_name)
        updated = @drenas.update(drena:)
        return updated if updated.failure?

        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "Drena",
                          subject_id: drena.id, metadata: { change: "drena.updated", name: drena.name, previous_name: })
        updated
      end
    end
  end
end
