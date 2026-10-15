require "test_helper"

module Queries
  module Assessment
    # ADR-0089 §4.1, PRD accueil-eleve CA-8 à CA-15 : l'exercice du jour se calcule à la lecture, à partir de la date
    # d'Abidjan et des sessions terminées. Le tour part du 2026-01-01 : le 2026-10-20 est le 292e jour, donc la 1re de deux
    # matières (292 % 2 = 0), et le 2026-10-21 la 2e.
    class DailyExerciseQueryTest < ActiveSupport::TestCase
      TUESDAY = Date.new(2026, 10, 20)

      setup do
        @classroom = create_classroom(level: create_level(name: "6e"), name: "6e A")
        @student = create_student(classroom: @classroom)
        @maths = create_material(name: "Mathématiques", category: "science")
        @svt = create_material(name: "SVT", category: "science")
        @maths_essential = create_essential(course: create_course(material: @maths, level: @classroom.level, name: "Nombres"))
        @fractions = create_exercise(essential: @maths_essential, title: "Les fractions")
        @decimals = create_exercise(essential: @maths_essential, title: "Les décimaux")
        @cell = create_exercise(essential: create_essential(course: create_course(material: @svt, level: @classroom.level)),
                                title: "La cellule")
      end

      def daily(today = TUESDAY, student: @student) = DailyExerciseQuery.new.call(student_id: student.id, today:)
      def at(day, hour, minute = 0) = Time.zone.local(day.year, day.month, day.day, hour, minute)

      def complete(exercise, started_at:, completed_at: started_at + 10.minutes, **)
        create_exercise_session(student: @student, exercise:, status: "completed", started_at:, completed_at:, **)
      end

      test "CA-8: without work from a teacher, the first unfinished exercise of the subject of the day is proposed" do
        row = travel_to(at(TUESDAY, 8)) { daily }

        assert_equal :proposed, row.state
        assert_equal [ @fractions.public_id, "Les fractions", "Mathématiques", "science" ],
                     row.to_h.values_at(:exercise_public_id, :exercise_title, :material_name, :material_category)
        assert_nil row.tomorrow_material_name
      end

      test "CA-9: the same exercise all day long, even once started and left unfinished" do
        morning = travel_to(at(TUESDAY, 8)) { daily }
        travel_to(at(TUESDAY, 9)) { create_exercise_session(student: @student, exercise: @fractions) }
        evening = travel_to(at(TUESDAY, 18)) { daily }

        assert_equal morning, evening
      end

      test "CA-10: once done, « Bravo, à demain ! » with the subject of tomorrow, and nothing else is proposed" do
        complete(@fractions, started_at: at(TUESDAY, 9))

        row = travel_to(at(TUESDAY, 18)) { daily }

        assert_equal :done_today, row.state
        assert_equal [ @fractions.public_id, "Les fractions", "Mathématiques", "SVT" ],
                     row.to_h.values_at(:exercise_public_id, :exercise_title, :material_name, :tomorrow_material_name)
      end

      test "a remediation finished today on the exercise of the day is not « done today »" do
        complete(@fractions, started_at: at(TUESDAY, 9), gap: create_gap(student: @student, essential: @maths_essential))

        row = travel_to(at(TUESDAY, 18)) { daily }

        assert_equal :proposed, row.state
      end

      # Revue sécurité de la PR : la portée n'est garantie que par la query, chaque refus a son test.
      test "never proposes an exercise of another level or series, nor after leaving or archiving the classroom" do
        Orm::Exercise.update_all(status: "draft")
        level = create_level(name: "2nde")
        series = create_series(name: "C")
        link_level_series(level:, series:)
        classroom = create_classroom(level:, series:)
        student = create_student(classroom:)
        other_level = create_course(material: @maths, level: create_level)
        other_series = create_course(material: @maths, level:, series: create_series(name: "A"))
        [ other_level, other_series ].each { create_exercise(essential: create_essential(course: it)) }

        assert_equal :none, travel_to(at(TUESDAY, 8)) { daily(student:) }.state

        own = create_exercise(essential: create_essential(course: create_course(material: @maths, level:, series:)))
        assert_equal own.public_id, travel_to(at(TUESDAY, 8)) { daily(student:) }.exercise_public_id

        Orm::ClassroomStudent.where(student:).update_all(left_at: Time.current)
        assert_equal :none, travel_to(at(TUESDAY, 8)) { daily(student:) }.state

        Orm::ClassroomStudent.where(student:).update_all(left_at: nil)
        Orm::Classroom.where(id: classroom.id).update_all(status: "archived", archived_at: Time.current)
        assert_equal :none, travel_to(at(TUESDAY, 8)) { daily(student:) }.state
      end

      test "the subject of tomorrow skips a subject left without candidates once today's exercise is done" do
        complete(@cell, started_at: at(TUESDAY - 3, 9))
        complete(@decimals, started_at: at(TUESDAY - 2, 9))
        complete(@fractions, started_at: at(TUESDAY, 9))

        row = travel_to(at(TUESDAY, 18)) { daily }

        assert_equal :done_today, row.state
        assert_nil row.tomorrow_material_name
      end

      test "CA-12: a subject without an unfinished published exercise is skipped for the next one" do
        complete(@fractions, started_at: at(TUESDAY - 2, 9))
        complete(@decimals, started_at: at(TUESDAY - 1, 9))

        row = travel_to(at(TUESDAY, 8)) { daily }

        assert_equal [ :proposed, @cell.public_id, "SVT" ], row.to_h.values_at(:state, :exercise_public_id, :material_name)
      end

      test "CA-13: nothing to propose when every exercise is done, or without a classroom" do
        [ @fractions, @decimals, @cell ].each_with_index { |exercise, index| complete(exercise, started_at: at(TUESDAY - 5 + index, 9)) }

        rows = travel_to(at(TUESDAY, 8)) { [ daily, daily(student: create_student) ] }

        rows.each do |row|
          assert_equal :none, row.state
          assert_equal [ nil ] * 5, row.to_h.except(:state).values
        end
      end

      test "CA-14: a session started at 23:50 and finished after midnight belongs to the day it started" do
        wednesday = TUESDAY + 1
        complete(@fractions, started_at: at(TUESDAY, 23, 50), completed_at: at(wednesday, 0, 10))

        tuesday_night = travel_to(at(wednesday, 0, 15)) { daily(TUESDAY) }
        wednesday_row = travel_to(at(wednesday, 0, 15)) { daily(wednesday) }
        thursday_row = travel_to(at(wednesday + 1, 8)) { daily(wednesday + 1) }

        assert_equal [ :done_today, @fractions.public_id ], tuesday_night.to_h.values_at(:state, :exercise_public_id)
        assert_equal [ :proposed, @cell.public_id ], wednesday_row.to_h.values_at(:state, :exercise_public_id)
        assert_equal [ :proposed, @decimals.public_id ], thursday_row.to_h.values_at(:state, :exercise_public_id)
      end

      test "CA-15: an exercise assigned in one of the student's classrooms is never proposed; archived or elsewhere, it is" do
        create_assignment(classroom: @classroom, assignable: @fractions)
        club = create_classroom(level: create_level)
        Orm::ClassroomStudent.create!(classroom: club, student: @student, primary: false, joined_at: Time.current, joined_via: "standard")
        create_assignment(classroom: club, assignable: @decimals)
        other = create_exercise(essential: @maths_essential, title: "Les pourcentages")
        create_assignment(classroom: @classroom, assignable: other, status: "archived")
        create_assignment(classroom: create_classroom(level: @classroom.level), assignable: other)

        row = travel_to(at(TUESDAY, 8)) { daily }

        assert_equal [ :proposed, other.public_id ], row.to_h.values_at(:state, :exercise_public_id)
      end

      test "the subjects are the union of the student's classrooms of the year, in the order of the chart" do
        club = create_classroom(level: create_level(name: "Club"))
        Orm::ClassroomStudent.create!(classroom: club, student: @student, primary: false, joined_at: Time.current, joined_via: "standard")
        physics = create_material(name: "Physique-Chimie", category: "science")
        current = create_exercise(essential: create_essential(course: create_course(material: physics, level: club.level)), title: "Ohm")
        last_year = create_classroom(level: create_level, school_year: "2024-2025")
        Orm::ClassroomStudent.create!(classroom: last_year, student: @student, primary: false, joined_at: Time.current, joined_via: "standard")
        create_exercise(essential: create_essential(course: create_course(material: create_material(name: "Anglais"), level: last_year.level)))

        # [mathematiques, physique-chimie, svt] : 292 % 3 = 1, 293 % 3 = 2, 294 % 3 = 0.
        rows = [ 0, 1, 2 ].map { |offset| travel_to(at(TUESDAY + offset, 8)) { daily(TUESDAY + offset) } }

        assert_equal [ current.public_id, @cell.public_id, @fractions.public_id ], rows.map(&:exercise_public_id)
      end

      test "the candidates follow the catalog: level, course name, sheet position, exercise position; published only" do
        algebra = create_course(material: @maths, level: @classroom.level, name: "Algèbre")
        create_exercise(essential: create_essential(course: algebra, status: "draft"), title: "Fiche brouillon")
        first_sheet = create_essential(course: algebra)
        create_exercise(essential: first_sheet, title: "Brouillon", status: "draft")
        second = create_exercise(essential: first_sheet, title: "Équations")
        create_exercise(essential: create_essential(course: create_course(material: @maths, level: @classroom.level,
                                                                                name: "Aaa", status: "draft")))

        row = travel_to(at(TUESDAY, 8)) { daily }

        assert_equal "Équations", row.exercise_title
        assert_equal second.public_id, row.exercise_public_id
      end

      test "another student's sessions change nothing" do
        other = create_student(classroom: @classroom)
        create_exercise_session(student: other, exercise: @fractions, status: "completed", started_at: at(TUESDAY - 1, 9))

        row = travel_to(at(TUESDAY, 8)) { daily }

        assert_equal @fractions.public_id, row.exercise_public_id
      end

      test "a single query, whatever the number of subjects and exercises; a subject outside the chart comes last" do
        create_exercise(essential: create_essential(course: create_course(material: create_material(name: "Anglais"),
                                                                                level: @classroom.level)))
        complete(@fractions, started_at: at(TUESDAY, 9))

        row = nil
        queries = travel_to(at(TUESDAY, 18)) { count_queries { row = daily } }

        assert_equal 1, queries
        # [mathematiques, svt, anglais] : 292 % 3 = 1 ; Anglais, par son nom, serait passé devant.
        assert_equal [ :proposed, @cell.public_id ], row.to_h.values_at(:state, :exercise_public_id)
      end

      private

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end
    end
  end
end
