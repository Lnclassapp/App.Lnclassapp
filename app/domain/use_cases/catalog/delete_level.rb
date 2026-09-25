# 🧠 DOMAINE · UseCases::Catalog::DeleteLevel
# Rôle : l'équipe supprime un niveau que rien n'utilise ; lié à une série, porté par une classe ou un cours : refus
# ADR  : 0026, 0028, 0034, 0036
module UseCases
  module Catalog
    class DeleteLevel
      def initialize(taxonomy:, audit_log:, transaction:, policy:, clock:)
        @taxonomy = taxonomy
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result | :forbidden | :not_found | :conflict (errors: { base: [:referenced] }), sans aucune cascade
      def call(actor:, slug:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        level = @taxonomy.find_level(slug:)
        return Shared::Result.failure(:not_found) if level.nil?

        @transaction.call { delete(actor, level) }
      end

      private

      def delete(actor, level)
        deleted = @taxonomy.delete_level(id: level.id)
        if deleted.success?
          @audit_log.record(action: "taxonomy.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "Level",
                            subject_id: level.id, metadata: { operation: "delete", slug: level.slug })
        end
        deleted
      end
    end
  end
end
