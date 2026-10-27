# 🔌 INFRASTRUCTURE · Catalog::ImportCourseSheetJob
# Rôle : job de l'import d'une fiche de cours en blocs : câble l'adaptateur Catalog::ImportCourseSheet sur les repositories réels
# ADR  : XXXX-fiche-de-cours-en-donnees-importees (contenu-en-blocs, #318), 0039, 0052
module Catalog
  class ImportCourseSheetJob < Shared::ImportJob
    private

    def adapter
      UseCases::Catalog::ImportCourseSheet.new(courses: Repositories::Catalog::CourseRepository.new,
                                               sheets: Repositories::Catalog::CourseSheetRepository.new)
    end
  end
end
