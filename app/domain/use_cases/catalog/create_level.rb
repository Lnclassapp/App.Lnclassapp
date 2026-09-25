# 🧠 DOMAINE · UseCases::Catalog::CreateLevel
# Rôle : l'équipe crée un niveau ; son slug, dérivé du nom puis figé, est le code de la génération des classes
# ADR  : 0026, 0028, 0029, 0034
module UseCases
  module Catalog
    class CreateLevel
      def initialize(taxonomy:, audit_log:, transaction:, policy:, clock:)
        @taxonomy = taxonomy
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Catalog::LevelInput. → Result(Level) | :forbidden | :invalid | :conflict (nom ou position pris)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        level = Entities::Catalog::Level.new(**dto.level_attributes)
        return Shared::Result.failure(:invalid, errors: level.errors.to_hash) unless level.valid?

        @transaction.call { create(actor, level) }
      end

      private

      def create(actor, level)
        created = @taxonomy.create_level(level:)
        if created.success?
          @audit_log.record(action: "taxonomy.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "Level",
                            subject_id: created.value.id, metadata: { operation: "create", slug: created.value.slug })
        end
        created
      end
    end
  end
end
