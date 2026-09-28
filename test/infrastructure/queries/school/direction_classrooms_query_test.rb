require "test_helper"

# ADR-0066 §4.6: the active classrooms of the current school year of one school, grouped by level, with their headcount and
# capacity — read by the filters (Lots C, E) and the choice of a classroom (Lot E).
module Queries
  module School
    class DirectionClassroomsQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school
        @sixth = create_level(name: "6ème", position: 1)
        @terminal = create_level(name: "Tle", position: 7)
        @query = DirectionClassroomsQuery.new
      end

      test "active classrooms of this school and this year, by level, with headcount and capacity" do
        second = create_classroom(school: @school, level: @sixth, name: "6ème 2", max_students: 60)
        tenth = create_classroom(school: @school, level: @sixth, name: "6ème 10")
        first = create_classroom(school: @school, level: @sixth, name: "6ème 1")
        d1 = create_classroom(school: @school, level: @terminal, series: create_series(name: "D"), name: "Tle D 1")
        a1 = create_classroom(school: @school, level: @terminal, series: create_series(name: "A"), name: "Tle A 1")
        2.times { create_student(classroom: second) }
        create_student(classroom: second).then do |gone|
          Orm::ClassroomStudent.where(student_id: gone.id).update_all(left_at: Time.current)
        end
        create_classroom(school: @school, level: @sixth, name: "6ème 3", status: "archived")
        create_classroom(school: @school, level: @sixth, name: "6ème 4", school_year: "2020-2021")
        create_classroom(school: create_school, level: @sixth, name: "6ème 1")

        levels = @query.call(school_id: @school.id)

        assert_equal [ "6ème", "Tle" ], levels.map(&:name)
        assert_equal [ first, second, tenth ].map(&:public_id), levels.first.classrooms.map(&:public_id)
        assert_equal [ a1, d1 ].map(&:public_id), levels.last.classrooms.map(&:public_id)
        row = levels.first.classrooms[1]
        assert_equal [ "6ème 2", "6ème", 2, 60 ], [ row.name, row.level_name, row.students_count, row.capacity ]
        assert_equal 0, levels.first.classrooms.first.students_count
      end

      test "the public ids of the classrooms, to check a filter or a choice" do
        classroom = create_classroom(school: @school, level: @sixth)
        other = create_classroom(level: @sixth)

        assert @query.includes?(school_id: @school.id, public_id: classroom.public_id)
        assert_not @query.includes?(school_id: @school.id, public_id: other.public_id)
        assert_not @query.includes?(school_id: @school.id, public_id: nil)
      end

      test "a school without classroom this year has no level" do
        assert_empty @query.call(school_id: @school.id)
      end
    end
  end
end
