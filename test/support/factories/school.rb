# DRENA and schools (ADR-0030, ADR-0034): created on screen by the team, never imported for DRENA.
module Factories
  module School
    ActiveSupport::TestCase.include(self)

    def create_drena(name: "DRENA #{factory_sequence}")
      Orm::Drena.create!(name:)
    end

    # ADR-0057: every school has its school code, drawn by the domain as the import does.
    def create_school(drena: create_drena, name: "Lycée moderne #{factory_sequence}", school_type: "public", cycle: "both",
                      status: "active", school_code: Entities::School::SchoolCode.generate, **attributes)
      Orm::School.create!(drena:, name:, school_type:, cycle:, status:, school_code:, **attributes)
    end

    # ADR-0071: the trace of a teacher withdrawn from a school, open until the direction reinstates him. Only the row:
    # the caller sets the teacher's school as the scenario needs it (`create_teacher(school: nil)` for a withdrawn one).
    def create_teacher_departure(teacher:, school:, detached_by:, reinstated: false, detached_at: 1.day.ago)
      Orm::TeacherSchoolDeparture.create!(teacher:, school:, detached_by:, detached_at:,
                                          reinstated_by: (detached_by if reinstated), reinstated_at: (Time.current if reinstated))
    end
  end
end
