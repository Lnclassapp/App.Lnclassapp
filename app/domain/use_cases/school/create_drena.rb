# 🧠 DOMAINE · UseCases::School::CreateDrena
# Rôle : l'équipe crée une DRENA à l'écran ; son slug, tiré du nom puis figé, est la cible des imports d'établissements
# ADR  : 0026, 0028, 0029, 0034
module UseCases
  module School
    class CreateDrena
      def initialize(drenas:, audit_log:, transaction:, policy:, clock:)
        @drenas = drenas
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::School::DrenaInput. → Result(Entities::School::Drena) | :forbidden | :invalid | :conflict (nom pris)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        @transaction.call { store(actor, Entities::School::Drena.new(name: dto.name)) }
      end

      private

      def store(actor, drena)
        created = @drenas.create(drena:)
        return created if created.failure?

        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "Drena",
                          subject_id: created.value.id, metadata: { change: "drena.created", name: created.value.name })
        created
      end
    end
  end
end
