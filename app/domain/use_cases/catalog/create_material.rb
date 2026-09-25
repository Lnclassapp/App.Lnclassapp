# 🧠 DOMAINE · UseCases::Catalog::CreateMaterial
# Rôle : crée une matière avec sa catégorie ; le slug, dérivé du nom par le dépôt, est ensuite figé ; journal taxonomy.changed
# ADR  : 0026, 0029, 0034, 0050
module UseCases
  module Catalog
    class CreateMaterial
      def initialize(taxonomy:, audit_log:, policy:, transaction:, clock:)
        @taxonomy = taxonomy
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # dto : Dtos::Catalog::MaterialInput. → Result(Material) | :forbidden | :invalid | :conflict (nom ou abrégé pris)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        @transaction.call do
          created = @taxonomy.create_material(material: Entities::Catalog::Material.new(**dto.to_h))
          record(actor, created.value) if created.success?
          created
        end
      end

      private

      def record(actor, material)
        @audit_log.record(action: "taxonomy.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "Material",
                          subject_id: material.id, metadata: { change: "created", slug: material.slug })
      end
    end
  end
end
