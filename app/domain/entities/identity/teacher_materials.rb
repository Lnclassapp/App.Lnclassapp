# 🧠 DOMAINE · Entities::Identity::TeacherMaterials
# Rôle : la liste des matières d'un enseignant dans un établissement : 1 à 3, sans doublon, dans l'ordre d'ajout
# ADR  : 0103
module Entities
  module Identity
    module TeacherMaterials
      MIN = 1
      MAX = 3

      # ids : identifiants de matières, dans l'ordre voulu. → ::Shared::Result (value : les ids dédoublonnés, ordre gardé)
      def self.build(ids)
        unique = ids.compact.uniq
        return ::Shared::Result.failure(:invalid, errors: { material_slugs: [ :blank ] }) if unique.size < MIN
        return ::Shared::Result.failure(:invalid, errors: { material_slugs: [ :too_many ] }) if unique.size > MAX

        ::Shared::Result.success(unique)
      end
    end
  end
end
