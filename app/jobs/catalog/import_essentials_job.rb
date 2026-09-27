# 🔌 INFRASTRUCTURE · Catalog::ImportEssentialsJob
# Rôle : job de l'import des fiches essentielles d'un cours : câble l'adaptateur Catalog::ImportEssentials sur les repositories réels
# ADR  : 0035, 0039, 0052
module Catalog
  class ImportEssentialsJob < Shared::ImportJob
    private

    def adapter
      UseCases::Catalog::ImportEssentials.new(
        courses: Repositories::Catalog::CourseRepository.new, essentials: Repositories::Catalog::EssentialRepository.new,
        writer: Repositories::Catalog::ContentTreeWriter.new
      )
    end
  end
end
