# 🧠 DOMAINE · UseCases::Catalog::DeleteMaterial
# Rôle : supprime une matière que ni un cours ni un profil enseignant ne référence ; jamais de cascade ; journal taxonomy.changed
# ADR  : 0026, 0034, 0036, 0050
module UseCases
  module Catalog
    class DeleteMaterial
      def initialize(taxonomy:, audit_log:, policy:, transaction:, clock:)
        @taxonomy = taxonomy
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # → Result | :forbidden | :not_found | :conflict (errors: { base: [:referenced] })
      def call(actor:, slug:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        material = @taxonomy.find_material(slug:)
        return Shared::Result.failure(:not_found) if material.nil?

        @transaction.call do
          deleted = @taxonomy.delete_material(id: material.id)
          record(actor, material) if deleted.success?
          deleted
        end
      end

      private

      def record(actor, material)
        @audit_log.record(action: "taxonomy.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "Material",
                          subject_id: material.id, metadata: { change: "deleted", slug: material.slug, name: material.name })
      end
    end
  end
end
