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

      def home(teacher = @teacher, school: @school, **) = TeacherHomeQuery.new.call(teacher_id: teacher.id, school_id: school.id, **)
      def card(row = home) = row.classrooms.sole

      test "the header: current school, subject and its category" do
        row = home

        assert_equal [ "Lycée Classique d'Abidjan", [ [ "SVT", "science" ] ] ],
                     [ row.school_name, row.materials.map { [ it.name, it.category ] } ]
        assert_not row.several_materials?
      end

      test "a declared classroom: public id, name, level, present students and active assignments" do
        2.times { create_student(classroom: @classroom) }
        gone = create_student(classroom: @classroom)
        Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
        create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
        create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher)
        create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher, status: "archived")

        assert_equal({ public_id: @classroom.public_id, name: "Tle D 1", level_name: "Tle", active_students_count: 2,
                       active_assignments_count: 2, join_code: Orm::Classroom.find(@classroom.id).join_code,
                       badge_counts: { bronze: 0, silver: 0, gold: 0, diamond: 0 } }, card.to_h)
      end

      # CA-G2, CA-G3 (UDR enseignant §3.2) : un badge par élève présent, chaque élève une fois ; « Pas encore » ne se compte pas.
      test "badge counts: one badge per present student, from the best score of each active assignment of the classroom" do
        exercises = Array.new(2) { create_exercise(essential: create_essential(course: create_course(material: @svt))) }
        assignments = exercises.map { create_assignment(classroom: @classroom, assignable: it, by: @teacher) }
        archived = create_assignment(classroom: @classroom, assignable: create_exercise, by: @teacher, status: "archived")
        elsewhere = create_assignment(classroom: create_classroom(school: @school), assignable: exercises.first, by: @teacher)
        students = Array.new(7) { create_student(classroom: @classroom) }
        gone = create_student(classroom: @classroom)
        Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
        score = lambda do |student, assignment, percent|
          create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed",
                                  classroom_assignment: assignment, score_percent: percent)
        end
        # diamant : sans faute partout ; or : 90 et 80 ; argent : 70 (la meilleure session de l'exercice compte) ; bronze : 55 ;
        # pas encore : 30, et un élève sans rien ; un élève parti, une assignation archivée et une session non terminée ne comptent pas.
        [ 100, 100 ].each_with_index { |percent, index| score.call(students[0], assignments[index], percent) }
        [ 90, 80 ].each_with_index { |percent, index| score.call(students[1], assignments[index], percent) }
        score.call(students[2], assignments[0], 40)
        score.call(students[2], assignments[0], 70)
        score.call(students[3], assignments[0], 55)
        score.call(students[4], assignments[0], 30)
        score.call(students[5], archived, 100)
        create_exercise_session(student: students[5], exercise: exercises.first, classroom_assignment: assignments[1], score_percent: 100)
        score.call(gone, assignments[0], 100)
        score.call(students[6], elsewhere, 100)

        assert_equal({ bronze: 1, silver: 1, gold: 1, diamond: 1 }, card.badge_counts)
      end

      test "badge counts: a student of two classrooms counts once in each, with the assignments of that classroom only" do
        other = create_classroom(school: @school, level: @tle, name: "Tle D 2")
        Orm::TeacherClassroom.create!(teacher: @teacher, classroom: other)
        student = create_student(classroom: @classroom)
        Orm::ClassroomStudent.create!(classroom: other, student:, primary: false, joined_at: Time.current, joined_via: "standard")
        exercise = create_exercise(essential: create_essential(course: create_course(material: @svt)))
        mine = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
        create_assignment(classroom: other, assignable: exercise, by: @teacher)
        create_exercise_session(student:, exercise:, status: "completed", classroom_assignment: mine, score_percent: 85)

        counts = home.classrooms.to_h { [ it.name, it.badge_counts.values.sum ] }

        assert_equal({ "Tle D 1" => 1, "Tle D 2" => 0 }, counts)
      end

      test "the school: its sigle, or nil without one" do
        assert_nil home.school_sigle
        @school.update!(sigle: "LCA")

        assert_equal "LCA", home.school_sigle
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
        assert_equal [ @svt.slug ], home.materials.map(&:slug)
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

      # ME-07 (ADR-0094 §4.6, UDR-0098 §3.3) : deux « 6ème 1 », une par établissement ; l'accueil ne lit que celle de
      # l'établissement courant, et nomme cet établissement.
      test "only the classrooms and course levels of the current school, named after it" do
        other = create_school(name: "Collège Saint-Michel")
        sixth = create_level(name: "6ème", position: 1)
        here = create_classroom(school: @school, level: sixth, name: "6ème 1")
        there = create_classroom(school: other, level: create_level(name: "5ème", position: 2), name: "6ème 1")
        Orm::TeacherSchool.create!(teacher: @teacher, school: other, primary: false)
        [ here, there ].each { Orm::TeacherClassroom.create!(teacher: @teacher, classroom: it) }

        in_other = home(school: other)

        assert_equal [ here.public_id, @classroom.public_id ], home.classrooms.map(&:public_id)
        assert_equal [ "Collège Saint-Michel", [ there.public_id ], [ "5ème" ] ],
                     [ in_other.school_name, in_other.classrooms.map(&:public_id), in_other.course_levels.map(&:label) ]
      end

      test "course levels: none without a declared classroom" do
        assert_empty home(create_teacher(school: @school)).course_levels
      end

      # Six reads before the bubbles (profile, school, classrooms, members, assignments, badges): one more at most.
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
