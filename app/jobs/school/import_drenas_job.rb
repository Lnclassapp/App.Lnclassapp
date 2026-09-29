# 🔌 INFRASTRUCTURE · School::ImportDrenasJob
# Rôle : job de l'import des DRENA : câble l'adaptateur School::ImportDrenas sur le repository réel
# ADR  : 0039, 0052, 0055
module School
  class ImportDrenasJob < Shared::ImportJob
    private

    def adapter = UseCases::School::ImportDrenas.new(drenas: Repositories::School::DrenaRepository.new)
  end
end
