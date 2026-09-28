# 🔌 INFRASTRUCTURE · School::ImportSchoolsJob
# Rôle : job de l'import des établissements : câble l'adaptateur School::ImportSchools sur les repositories réels
# ADR  : 0030, 0039, 0052, 0058
module School
  class ImportSchoolsJob < Shared::ImportJob
    private

    def adapter
      UseCases::School::ImportSchools.new(
        drenas: Repositories::School::DrenaRepository.new, schools: Repositories::School::SchoolRepository.new,
        classrooms: Repositories::Classroom::ClassroomRepository.new, taxonomy: Repositories::Catalog::TaxonomyRepository.new,
        classroom_plan: Repositories::Classroom::ClassroomPlanRepository.new
      )
    end
  end
end
