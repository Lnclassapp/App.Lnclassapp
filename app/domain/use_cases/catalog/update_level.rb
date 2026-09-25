# 🧠 DOMAINE · UseCases::Catalog::UpdateLevel
# Rôle : l'équipe modifie le nom, la position ou le cycle d'un niveau ; son slug ne change jamais
# ADR  : 0026, 0028, 0029, 0034
module UseCases
  module Catalog
    class UpdateLevel
      def initialize(taxonomy:, audit_log:, transaction:, policy:, clock:)
        @taxonomy = taxonomy
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Catalog::LevelInput. → Result(Level) | :forbidden | :not_found | :invalid | :conflict
      def call(actor:, slug:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        current = @taxonomy.find_level(slug:)
        return Shared::Result.failure(:not_found) if current.nil?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        # L'identifiant et le slug viennent du niveau enregistré, jamais de la saisie (ADR-0029).
        level = Entities::Catalog::Level.new(id: current.id, slug: current.slug, **dto.level_attributes)
        return Shared::Result.failure(:invalid, errors: level.errors.to_hash) unless level.valid?

        @transaction.call { update(actor, level) }
      end

      private

      def update(actor, level)
        updated = @taxonomy.update_level(level:)
        if updated.success?
          @audit_log.record(action: "taxonomy.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "Level",
                            subject_id: level.id, metadata: { operation: "update", slug: level.slug })
        end
        updated
      end
    end
  end
end
