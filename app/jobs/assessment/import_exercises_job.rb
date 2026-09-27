# 🔌 INFRASTRUCTURE · Assessment::ImportExercisesJob
# Rôle : job de l'import des exercices d'une fiche : câble l'adaptateur Assessment::ImportExercises sur les repositories réels
# ADR  : 0035, 0039, 0052
module Assessment
  class ImportExercisesJob < Shared::ImportJob
    private

    def adapter
      UseCases::Assessment::ImportExercises.new(
        essentials: Repositories::Catalog::EssentialRepository.new, exercises: Repositories::Assessment::ExerciseRepository.new,
        writer: Repositories::Catalog::ContentTreeWriter.new
      )
    end
  end
end
