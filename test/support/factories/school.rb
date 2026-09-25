# DRENA and schools (ADR-0030, ADR-0034): created on screen by the team, never imported for DRENA.
module Factories
  module School
    ActiveSupport::TestCase.include(self)

    def create_drena(name: "DRENA #{factory_sequence}")
      Orm::Drena.create!(name:)
    end

    def create_school(drena: create_drena, name: "Lycée moderne #{factory_sequence}", school_type: "public", cycle: "both",
                      status: "active", **attributes)
      Orm::School.create!(drena:, name:, school_type:, cycle:, status:, **attributes)
    end
  end
end
