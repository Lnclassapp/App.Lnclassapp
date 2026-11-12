require "test_helper"

module Queries
  module Catalog
    # UDR-0013, amendement du 2026-10-01 : le niveau d'un élève, ce sont ses classes actives de l'année, non quittées ; sans
    # aucune, sa dernière classe principale (ADR-0035, amendement eleve-sans-prof).
    class StudentAudienceQueryTest < ActiveSupport::TestCase
      test "les classes actives de l'année où l'élève est encore ; ni une classe quittée, ni archivée, ni d'une autre année" do
        tle = create_level(name: "Tle")
        d = create_series(name: "D")
        student = create_student(classroom: create_classroom(level: tle, series: d))
        seconde = create_level(name: "2nde")
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom: create_classroom(level: seconde), student:, joined_at: Time.current)
        [ create_classroom(level: create_level, status: "archived"),
          create_classroom(level: create_level, school_year: current_school_year(on: 1.year.ago.to_date)) ].each do |classroom|
          Orm::ClassroomStudent.create!(joined_via: "standard", classroom:, student:, joined_at: Time.current)
        end
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom: create_classroom(level: create_level), student:, joined_at: 2.days.ago,
                                      left_at: 1.day.ago)

        audience = StudentAudienceQuery.new.call(student_id: student.id)

        assert_equal [ [ seconde.id, nil ], [ tle.id, d.id ] ].sort_by(&:first), audience.pairs.sort_by(&:first)
        assert StudentAudienceQuery.new.call(student_id: create_student.id).empty?
      end

      # Chantier eleve-sans-prof : sans classe active de l'année, le niveau de sa dernière classe principale.
      test "without an active classroom of the year, the level of the last primary classroom; never had one: empty" do
        tle = create_level(name: "Tle")
        d = create_series(name: "D")
        student = create_student(classroom: create_classroom(level: create_level(name: "1ère"), status: "archived"), joined_at: 1.year.ago)
        Orm::ClassroomStudent.where(student:).update_all(left_at: 6.months.ago)
        last = create_classroom(level: tle, series: d)
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom: last, student:, primary: true,
                                      joined_at: 5.months.ago, left_at: 1.day.ago)
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom: create_classroom(level: create_level), student:, primary: false,
                                      joined_at: 2.hours.ago, left_at: 1.hour.ago)

        assert_equal [ [ tle.id, d.id ] ], StudentAudienceQuery.new.call(student_id: student.id).pairs

        Orm::ClassroomStudent.where(classroom: last).update_all(left_at: nil)
        Orm::Classroom.where(id: last.id).update_all(school_year: current_school_year(on: 1.year.ago.to_date))
        assert_equal [ [ tle.id, d.id ] ], StudentAudienceQuery.new.call(student_id: student.id).pairs, "a classroom of a past year"
      end
    end
  end
end
