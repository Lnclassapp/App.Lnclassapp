# Classrooms and their assignments (ADR-0040, ADR-0041, ADR-0048, ADR-0072).
module Factories
  module Classroom
    ActiveSupport::TestCase.include(self)

    # The link token is drawn by the database (ADR-0085 §4.1); there is no classroom code any more.
    def create_classroom(school: create_school, level: create_level, series: nil, name: "Classe #{factory_sequence}",
                         status: "active", max_students: 80, school_year: current_school_year, **attributes)
      Orm::Classroom.create!(school:, level:, series:, name:, status:, max_students:, school_year:,
                             archived_at: (Time.current if status == "archived"), **attributes)
    end

    # assignable: an Orm::Exercise, the only assignable resource (ADR-0072 §4.1).
    def create_assignment(classroom: create_classroom, assignable: create_exercise, by: create_teacher, status: "active",
                          **attributes)
      Orm::ClassroomAssignment.create!(classroom:, assignable_type: assignable.class.name.demodulize, assignable_id: assignable.id,
                                       assigned_by: by, assigned_at: Time.current, status:,
                                       archived_at: (Time.current if status == "archived"),
                                       archived_by: (by if status == "archived"), **attributes)
    end

    # The Ivorian school year starts in September (ADR-0041).
    def current_school_year(on: Date.current)
      start = on.month >= 9 ? on.year : on.year - 1
      "#{start}-#{start + 1}"
    end
  end
end
