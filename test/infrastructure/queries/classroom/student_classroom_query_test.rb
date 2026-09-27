require "test_helper"

module Queries
  module Classroom
    # CL-22 (CS#B13): « Ma classe » reads the primary classroom only, and lists the courses assigned to it that are still
    # active and published, with their published sheets. The old screen kept showing the courses a teacher had withdrawn.
    class StudentClassroomQueryTest < ActiveSupport::TestCase
      setup do
        @classroom = create_classroom(school: create_school(name: "Lycée Classique"), level: create_level(name: "Tle"),
                                      series: create_series(name: "D"), name: "Tle D 1", school_year: "2026-2027")
        @student = create_student(classroom: @classroom)
        @svt = create_material(name: "SVT", category: "science")
      end

      def classroom(student = @student) = StudentClassroomQuery.new.call(student_id: student.id)
      def names(row = classroom) = row.courses.map(&:name)

      test "the header of the primary classroom, and no roster" do
        create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yapo")

        row = classroom

        assert_equal [ @classroom.public_id, "Tle D 1", "Tle", "D", "Lycée Classique", "2026-2027" ],
                     row.to_h.values_at(:public_id, :classroom_name, :level_name, :series_name, :school_name, :school_year)
        assert_equal %i[public_id classroom_name level_name series_name school_name school_year courses], row.to_h.keys
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

      test "the assigned courses, by name, with their subject and their published sheets" do
        genetique = create_course(name: "Génétique", subtitle: "Du gène au caractère", material: @svt)
        2.times { create_essential(course: genetique) }
        create_essential(course: genetique, status: "draft")
        create_assignment(classroom: @classroom, assignable: genetique)
        create_assignment(classroom: @classroom, assignable: create_course(name: "Écologie"))

        row = classroom

        assert_equal [ "Écologie", "Génétique" ], names(row)
        assert_equal [ genetique.slug, "Du gène au caractère", "SVT", "science", 2 ],
                     row.courses.last.to_h.values_at(:slug, :subtitle, :material_name, :material_category, :essentials_count)
        assert_equal 0, row.courses.first.essentials_count
      end

      test "non-regression CS#B13: a withdrawn, archived or draft course is absent, and so is a sheet or an exercise" do
        create_assignment(classroom: @classroom, assignable: create_course(name: "Retiré"), status: "archived")
        create_assignment(classroom: @classroom, assignable: create_course(name: "Archivé", status: "archived"))
        create_assignment(classroom: @classroom, assignable: create_course(name: "Brouillon", status: "draft"))
        create_assignment(classroom: @classroom, assignable: create_essential)
        create_assignment(classroom: @classroom, assignable: create_exercise)

        assert_empty names
      end

      test "the primary classroom only" do
        other = create_classroom
        Orm::ClassroomStudent.create!(classroom: other, student: @student, primary: false, joined_at: Time.current)
        create_assignment(classroom: other, assignable: create_course(name: "Autre classe"))

        assert_equal @classroom.public_id, classroom.public_id
        assert_empty names
      end
    end
  end
end
