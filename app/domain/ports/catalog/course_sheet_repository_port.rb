# 🧠 DOMAINE · Ports::Catalog::CourseSheetRepositoryPort
# Rôle : contrat de persistance de la fiche de cours d'une leçon (gelé par le Lot 0, contenu-en-blocs)
# ADR  : 0110-fiche-de-cours-en-donnees-importees
module Ports
  module Catalog
    module CourseSheetRepositoryPort
      # → Entities::Catalog::CourseSheet | nil
      def find_by_course_id(course_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_course_id"
      end

      # → true | false
      def exists_for_course?(course_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #exists_for_course?"
      end

      # Une fiche par leçon. → Result(CourseSheet) | failure(:conflict, errors: { course_id: [:taken] })
      def create(sheet:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end
    end
  end
end
