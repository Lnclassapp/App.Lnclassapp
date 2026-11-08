# 🔌 INFRA · Queries::Catalog::CourseMaterialQuery
# Rôle : la matière (slug) du cours d'un contenu, que juge ReadOwnMaterialPolicy
# ADR  : 0035, 0103 · UDR : 0077 (§3.2) · audit B-046
module Queries
  module Catalog
    class CourseMaterialQuery
      # Une seule clé : le slug ou l'id du cours. → String | nil (inconnu)
      def call(course_slug: nil, course_id: nil)
        scope = course_slug ? Orm::Course.where(slug: course_slug) : Orm::Course.where(id: course_id)
        scope.joins(:material).pick("materials.slug")
      end
    end
  end
end
