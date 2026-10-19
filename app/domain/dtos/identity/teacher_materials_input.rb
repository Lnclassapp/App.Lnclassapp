# 🧠 DOMAINE · Dtos::Identity::TeacherMaterialsInput
# Rôle : forme de « Mes matières » : les slugs cochés, dans l'ordre du formulaire ; la règle 1 à 3 est au use case
# ADR  : 0103 (§4.4) · UDR : 0125 (§3.3)
module Dtos
  module Identity
    class TeacherMaterialsInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Un slug figé (ADR-0029) ; toute autre forme (tableau imbriqué, octet nul…) est oubliée avant la base.
      SLUG = /\A[a-z0-9-]{1,64}\z/
      # Au-delà, la liste est déjà refusée (« 3 matières au plus ») : on n'en garde pas davantage à résoudre.
      KEPT = Entities::Identity::TeacherMaterials::MAX + 1

      attribute :material_slugs, default: -> { [] }

      def material_slugs=(raw)
        super(Array(raw).grep(String).select { SLUG.match?(it) }.uniq.first(KEPT))
      end
    end
  end
end
