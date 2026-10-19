# 🔌 INFRA · Queries::Catalog::HomepageMaterialsQuery
# Rôle : la bande « Matières » de la homepage : les matières qui ont au moins un cours publié, dans l'ordre du programme
# ADR  : 0099 (§4.2), 0090 (§4.2) · UDR : 0113 (§3.9)
module Queries
  module Catalog
    class HomepageMaterialsQuery
      # Une requête. → [[slug, name, category]]
      def call
        PublicCourses.scope.group("materials.id").order(*PublicCourses::MATERIAL_ORDER)
                     .pluck("materials.slug", "materials.name", "materials.category")
      end
    end
  end
end
