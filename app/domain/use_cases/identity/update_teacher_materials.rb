# 🧠 DOMAINE · UseCases::Identity::UpdateTeacherMaterials
# Rôle : l'enseignant remplace, en entier, la liste de ses matières (1 à 3) de son établissement courant ; chaque changement est tracé
# ADR  : 0055, 0094 (§4.2), 0103 (§4.2, §4.4) · UDR : 0125 (§3.3)
module UseCases
  module Identity
    class UpdateTeacherMaterials
      def initialize(teacher_materials:, taxonomy:, audit_log:, transaction:, policy:, clock:)
        @teacher_materials = teacher_materials
        @taxonomy = taxonomy
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Identity::TeacherMaterialsInput. Le compte et l'établissement sont ceux de l'acteur, jamais un paramètre.
      # → success | :forbidden | :invalid (material_slugs : blank, too_many, inclusion), rien n'est écrit
      def call(actor:, dto:, ip:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        slugs = dto.material_slugs
        # Le compte d'abord : un formulaire forgé de 50 slugs ne déclenche pas 50 lectures.
        counted = Entities::Identity::TeacherMaterials.build(slugs)
        return counted if counted.failure?

        materials = slugs.map { @taxonomy.find_material(slug: it) }
        return Shared::Result.failure(:invalid, errors: { material_slugs: [ :inclusion ] }) if materials.any?(&:nil?)

        store(actor, materials, ip)
      end

      private

      def store(actor, materials, ip)
        before = @teacher_materials.material_ids_for(teacher_id: actor.user_id, school_id: actor.school_id)
        after = materials.map(&:id)
        # Rien ne change (même ensemble, quel que soit l'ordre envoyé) : aucune écriture, aucune trace.
        return Shared::Result.success if before.sort == after.sort

        now = @clock.now
        @transaction.call do
          written = @teacher_materials.replace(teacher_id: actor.user_id, school_id: actor.school_id, material_ids: after, at: now)
          # Retiré de l'établissement entre-temps : rien n'est écrit, rien n'est tracé.
          next Shared::Result.failure(:forbidden) unless written

          @audit_log.record(action: "profile.materials_changed", actor_id: actor.user_id, at: now, subject_type: "User",
                            subject_id: actor.user_id, metadata: { school_id: actor.school_id, from: before, to: stored_order(before, after) }, ip:)
          Shared::Result.success
        end
      end

      # L'ordre réellement stocké : les matières gardées gardent leur rang, les nouvelles suivent dans l'ordre envoyé.
      def stored_order(before, after) = (before & after) + (after - before)
    end
  end
end
