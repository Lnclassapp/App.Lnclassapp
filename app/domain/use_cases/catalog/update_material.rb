# 🧠 DOMAINE · UseCases::Catalog::UpdateMaterial
# Rôle : modifie nom, abrégé et catégorie d'une matière ; le slug ne change jamais ; journal taxonomy.changed
# ADR  : 0026, 0029, 0034, 0050
module UseCases
  module Catalog
    class UpdateMaterial
      def initialize(taxonomy:, audit_log:, policy:, transaction:, clock:)
        @taxonomy = taxonomy
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # dto : Dtos::Catalog::MaterialInput. → Result(Material) | :forbidden | :not_found | :invalid | :conflict
      def call(actor:, slug:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        current = @taxonomy.find_material(slug:)
        return Shared::Result.failure(:not_found) if current.nil?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        @transaction.call do
          updated = @taxonomy.update_material(material: Entities::Catalog::Material.new(id: current.id, slug: current.slug, **dto.to_h))
          record(actor, current, updated.value) if updated.success?
          updated
        end
      end

      private

      def record(actor, before, after)
        changes = %w[name shortname category].to_h { [ it, [ before.public_send(it), after.public_send(it) ] ] }
                                            .reject { |_, (from, to)| from == to }
        @audit_log.record(action: "taxonomy.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "Material",
                          subject_id: after.id, metadata: { change: "updated", slug: after.slug, changes: })
      end
    end
  end
end
