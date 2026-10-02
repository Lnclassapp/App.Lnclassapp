require "test_helper"

module Queries
  module Classroom
    # CL-22 (CS#B13): « Ma classe » reads the primary classroom only. ADR-0072, UDR-0011 (amended 2026-10-02): a course is
    # no longer assigned, so « Ma classe » lists no course at all.
    class StudentClassroomQueryTest < ActiveSupport::TestCase
      setup do
        @classroom = create_classroom(school: create_school(name: "Lycée Classique"), level: create_level(name: "Tle"),
                                      series: create_series(name: "D"), name: "Tle D 1", school_year: "2026-2027")
        @student = create_student(classroom: @classroom)
        @svt = create_material(name: "SVT", category: "science")
      end

      def classroom(student = @student) = StudentClassroomQuery.new.call(student_id: student.id)

      test "the header of the primary classroom, and no roster" do
        create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yapo")

        row = classroom

        assert_equal [ @classroom.public_id, "Tle D 1", "Tle", "D", "Lycée Classique", "2026-2027" ],
                     row.to_h.values_at(:public_id, :classroom_name, :level_name, :series_name, :school_name, :school_year)
        assert_equal %i[public_id classroom_name level_name series_name school_name school_year], row.to_h.keys
        assert_no_match "Yapo", row.inspect
      end

      test "a classroom without series" do
        assert_nil classroom(create_student(classroom: create_classroom(series: nil))).series_name
      end

      test "no active primary classroom: nil" do
        assert_nil classroom(create_student)
        assert_nil classroom(create_student(classroom: create_classroom(status: "archived")))

        left = create_student(classroom: @classroom)
        Orm::ClassroomStudent.where(student: left).update_all(left_at: Time.current)
        assert_nil classroom(left)

        secondary = create_user(role: "student")
        Orm::ClassroomStudent.create!(classroom: @classroom, student: secondary, primary: false, joined_at: Time.current)
        assert_nil classroom(secondary)
      end

      test "no assigned courses any more: an assigned exercise, active or withdrawn, adds nothing to the row" do
        create_assignment(classroom: @classroom, assignable: create_exercise(essential: create_essential(course: create_course(material: @svt))))
        create_assignment(classroom: @classroom, assignable: create_exercise, status: "archived")

        row = classroom

        assert_not_includes StudentClassroomQuery::Row.members, :courses
        assert_equal @classroom.public_id, row.public_id
      end

      test "the primary classroom only" do
        other = create_classroom
        Orm::ClassroomStudent.create!(classroom: other, student: @student, primary: false, joined_at: Time.current)
        create_assignment(classroom: other)

        assert_equal @classroom.public_id, classroom.public_id
      end
    end
  end
end
