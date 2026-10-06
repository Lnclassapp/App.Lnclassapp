require "test_helper"

module Queries
  module Classroom
    # TR-05 (UDR-0026): the teacher home lists the active classrooms of the current school year the teacher declared,
    # each with its headcount, its active assignments and the average score in the teacher's subject. The old feed
    # raised NameError as soon as the teacher had a classroom.
    class TeacherHomeQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school(name: "Lycée Classique d'Abidjan")
        @svt = create_material(name: "SVT", category: "science")
        @tle = create_level(name: "Tle", position: 7)
        @classroom = create_classroom(school: @school, level: @tle, name: "Tle D 1")
        @teacher = create_teacher(school: @school, material: @svt, classrooms: [ @classroom ])
      end

      def home(teacher = @teacher, **) = TeacherHomeQuery.new.call(teacher_id: teacher.id, **)
      def card(row = home) = row.classrooms.sole

      test "the header: primary school, subject and its category" do
        row = home

        assert_equal [ "Lycée Classique d'Abidjan", "SVT", "science" ],
                     row.to_h.values_at(:school_name, :material_name, :material_category)
      end

      test "a declared classroom: public id, name, level, present students and active assignments" do
        2.times { create_student(classroom: @classroom) }
        gone = create_student(classroom: @classroom)
        Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
        create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
        create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
        create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher, status: "archived")

        assert_equal({ public_id: @classroom.public_id, name: "Tle D 1", level_name: "Tle", active_students_count: 2,
                       active_assignments_count: 2, average_score_percent: nil }, card.to_h)
      end

      test "the average score: completed sessions of present students, in the teacher's subject only" do
        svt_exercise = create_exercise(essential: create_essential(course: create_course(material: @svt)))
        maths_exercise = create_exercise(essential: create_essential(course: create_course(material: create_material)))
        awa = create_student(classroom: @classroom)
        koffi = create_student(classroom: @classroom)
        gone = create_student(classroom: @classroom)
        Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
        outsider = create_student(classroom: create_classroom(school: @school))
        create_exercise_session(student: awa, exercise: svt_exercise, status: "completed", score_percent: 80)
        create_exercise_session(student: awa, exercise: svt_exercise, status: "completed", score_percent: 50)
        create_exercise_session(student: koffi, exercise: svt_exercise, status: "completed", score_percent: 75)
        create_exercise_session(student: koffi, exercise: svt_exercise)
        create_exercise_session(student: koffi, exercise: maths_exercise, status: "completed", score_percent: 0)
        create_exercise_session(student: gone, exercise: svt_exercise, status: "completed", score_percent: 0)
        create_exercise_session(student: outsider, exercise: svt_exercise, status: "completed", score_percent: 0)

        assert_equal 68, card.average_score_percent
      end

      test "only the declared, active classrooms of the current school year" do
        create_classroom(school: @school, level: @tle, name: "Tle D 2")
        archived = create_classroom(school: @school, level: @tle, name: "Tle D 3", status: "archived")
        last_year = create_classroom(school: @school, level: @tle, name: "Tle D 4", school_year: "2000-2001")
        [ archived, last_year ].each { Orm::TeacherClassroom.create!(teacher: @teacher, classroom: it) }
        create_teacher(school: @school, classrooms: [ create_classroom(school: @school, level: @tle, name: "Tle C 1") ])

        assert_equal [ "Tle D 1" ], home.classrooms.map(&:name)
      end

      test "the school year is the one of the given day" do
        september = Date.new(2001, 9, 15)
        next_year = create_classroom(school: @school, level: @tle, name: "Tle D 9", school_year: "2001-2002")
        Orm::TeacherClassroom.create!(teacher: @teacher, classroom: next_year)

        assert_equal [ "Tle D 9" ], home(today: september).classrooms.map(&:name)
      end

      test "sorted by level, then by name, numbers compared as numbers" do
        sixth = create_level(name: "6ème", position: 1)
        [ [ @tle, "Tle A 1" ], [ sixth, "6ème 10" ], [ sixth, "6ème 2" ] ].each do |level, name|
          Orm::TeacherClassroom.create!(teacher: @teacher, classroom: create_classroom(school: @school, level:, name:))
        end

        assert_equal [ "6ème 2", "6ème 10", "Tle A 1", "Tle D 1" ], home.classrooms.map(&:name)
      end

      test "no declared classroom: an empty list" do
        assert_empty home(create_teacher(school: @school)).classrooms
      end

      # RE-13 (UDR-0069 §3.3): the « Cours » bubbles of the home, one per level and series taught.
      def levels(row = home) = row.course_levels.map { [ it.level_slug, it.series_slug, it.label ] }

      test "the subject slug, which picks the drawing of the bubbles" do
        assert_equal @svt.slug, home.material_slug
      end

      test "course levels: one per distinct level and series, sorted by level, no series first, then by series name" do
        third = create_level(name: "3ème", position: 4)
        first = create_level(name: "1ère", position: 6)
        d, a, c = %w[D A C].map { create_series(name: it) }
        [ [ @tle, d, "Tle D 2" ], [ @tle, a, "Tle A 1" ], [ @tle, nil, "Tle 1" ], [ first, c, "1ère C 1" ],
          [ third, nil, "3ème 2" ], [ third, nil, "3ème 1" ], [ @tle, d, "Tle D 3" ] ].each do |level, series, name|
          Orm::TeacherClassroom.create!(teacher: @teacher, classroom: create_classroom(school: @school, level:, series:, name:))
        end

        assert_equal [ [ third.slug, nil, "3ème" ], [ first.slug, c.slug, "1ère C" ], [ @tle.slug, nil, "Tle" ],
                       [ @tle.slug, a.slug, "Tle A" ], [ @tle.slug, d.slug, "Tle D" ] ], levels
      end

      test "course levels: neither archived classrooms, nor another school year, nor undeclared classrooms" do
        archived = create_classroom(school: @school, level: create_level(name: "4ème", position: 3), name: "4ème 1",
                                    status: "archived")
        last_year = create_classroom(school: @school, level: create_level(name: "5ème", position: 2), name: "5ème 1",
                                     school_year: "2000-2001")
        [ archived, last_year ].each { Orm::TeacherClassroom.create!(teacher: @teacher, classroom: it) }
        create_teacher(school: @school, classrooms: [ create_classroom(school: @school, level: create_level(name: "6ème"), name: "6ème 1") ])

        assert_equal [ [ @tle.slug, nil, "Tle" ] ], levels
      end

      test "course levels: none without a declared classroom" do
        assert_empty home(create_teacher(school: @school)).course_levels
      end

      # Six reads before the bubbles (profile, school, classrooms, members, assignments, scores): one more at most.
      test "course levels cost at most one more query, whatever the number of levels" do
        4.times do |index|
          level = create_level(name: "Niveau #{index}", position: index + 1)
          Orm::TeacherClassroom.create!(teacher: @teacher, classroom: create_classroom(school: @school, level:, series: create_series))
        end
        queries = 0
        counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }

        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { assert_equal 5, home.course_levels.size }

        assert_operator queries, :<=, 7
      end
    end
  end
end
