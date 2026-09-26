# 🔌 INFRASTRUCTURE · Catalog::ImportCourseTreeJob
# Rôle : job de l'import des cours complets : câble l'adaptateur Catalog::ImportCourseTree sur les repositories réels
# ADR  : 0035, 0039, 0052
module Catalog
  class ImportCourseTreeJob < Shared::ImportJob
    private

    def adapter
      UseCases::Catalog::ImportCourseTree.new(
        courses: Repositories::Catalog::CourseRepository.new, essentials: Repositories::Catalog::EssentialRepository.new,
        taxonomy: Repositories::Catalog::TaxonomyRepository.new, writer: Repositories::Catalog::ContentTreeWriter.new
      )
    end
  end
end
