# 🧠 DOMAINE · Policies::Catalog::ReadOwnMaterialPolicy
# Rôle : un enseignant ne lit par son adresse que les leçons de ses matières (celles de son établissement courant), comme le catalogue ; les autres rôles, tout
# ADR  : 0028, 0035, 0103 · UDR : 0077 (§3.2), XXXX leçon par adresse limitée aux matières de l'enseignant (audit B-046)
module Policies
  module Catalog
    class ReadOwnMaterialPolicy
      # own_material_slugs : les matières de l'enseignant dans son établissement courant ; material_slug : celle de la leçon lue.
      # Hors de ses matières : :not_found, comme un brouillon, sans rien confirmer.
      def call(actor:, own_material_slugs:, material_slug:)
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success unless actor.teacher?
        return Shared::Result.success if own_material_slugs.include?(material_slug)

        Shared::Result.failure(:not_found)
      end
    end
  end
end
