require "test_helper"

# CA-29, CA-30 (ADR-XXXX modèles de langage, « Données envoyées ») : les chiffres d'une école sur 30 jours, agrégats seulement ;
# nombre de requêtes constant.
module Queries
  module Crm
    class PedagogyReportQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school
        @level = create_level(name: "Tle", position: 7)
        @classroom = create_classroom(school: @school, level: @level, name: "Tle D 1")
        @teacher = create_teacher(school: @school)
        @maths = create_material(name: "Mathématiques", shortname: "Maths")
        @french = create_material(name: "Français", shortname: "Fr")
        @maths_course = create_course(level: @level, material: @maths, name: "Maths Tle")
        @french_course = create_course(level: @level, material: @french, name: "Français Tle")
      end

      def query(**) = PedagogyReportQuery.new.call(school_id: @school.id, **)

      def done(student, exercise, score, at: 2.days.ago, **attributes)
        create_exercise_session(student:, exercise:, status: "completed", score_percent: score, started_at: at, completed_at: at, **attributes)
      end

      test "an unknown school is nil, by public_id or id" do
        assert_nil PedagogyReportQuery.new.call(public_id: "unknown-public")
        assert_nil PedagogyReportQuery.new.call(school_id: 0)
        assert_equal query, PedagogyReportQuery.new.call(public_id: @school.public_id)
      end

      test "CA-30: a school with nothing in 30 days has zeros and no activity" do
        create_student(classroom: @classroom)

        report = query

        assert_not report.activity?
        assert_equal [ 0, 0, nil, nil, [], [] ], report.to_h.values_at(:active_students_count, :assignments_count, :submission_rate, :average_percent, :subjects, :gaps)
      end

      test "active students, success per subject and the overall average over the last 30 days only" do
        one = create_student(classroom: @classroom)
        two = create_student(classroom: @classroom)
        maths = create_exercise(course: @maths_course)
        french = create_exercise(course: @french_course)
        done(one, maths, 80)
        done(two, maths, 60)
        done(one, french, 50)
        done(two, maths, 10, at: 40.days.ago)
        create_exercise_session(student: one, exercise: maths, status: "started")

        report = query

        assert_equal 2, report.active_students_count
        assert_equal [ { name: "Français", category: @french.category, average_percent: 50, sessions_count: 1 },
                       { name: "Mathématiques", category: @maths.category, average_percent: 70, sessions_count: 2 } ], report.subjects
        assert_equal 63, report.average_percent
      end

      test "a student of another school, an anonymized one and a departed one are not counted" do
        other = create_student(classroom: create_classroom(school: create_school))
        departed = create_student(classroom: @classroom)
        Orm::ClassroomStudent.where(student: departed).update_all(left_at: 1.day.ago)
        exercise = create_exercise(course: @maths_course)
        [ other, departed ].each { done(it, exercise, 90) }

        assert_equal 0, query.active_students_count
      end

      test "the submission rate: students who handed in over students who were asked, on the assignments of the last 30 days" do
        students = Array.new(4) { create_student(classroom: @classroom) }
        exercise = create_exercise(course: @maths_course)
        first = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
        create_assignment(classroom: @classroom, assignable: create_exercise(course: @maths_course), by: @teacher, assigned_at: 40.days.ago, due_on: nil)
        create_assignment(classroom: @classroom, assignable: create_exercise(course: @maths_course), by: @teacher, status: "archived")
        done(students[0], exercise, 90, classroom_assignment: first)
        done(students[0], exercise, 95, classroom_assignment: first)
        done(students[1], exercise, 70, classroom_assignment: first)

        report = query

        assert_equal 1, report.assignments_count
        assert_equal 50, report.submission_rate
      end

      test "assignments without any student have no rate" do
        create_assignment(classroom: @classroom, assignable: create_exercise(course: @maths_course), by: @teacher)

        report = query

        assert_equal 1, report.assignments_count
        assert_nil report.submission_rate
        assert report.activity?
      end

      test "the five most frequent gaps, with the number of students and never a name" do
        students = Array.new(3) { create_student(classroom: @classroom, first_name: "Prénom#{it}") }
        essentials = Array.new(6) { |index| create_essential(course: @maths_course, name: "Fiche #{index}") }
        essentials.each_with_index { |essential, index| students.first(index.zero? ? 3 : 1).each { create_gap(student: it, essential:) } }
        create_gap(student: students[1], essential: essentials[1])
        create_gap(student: students[0], essential: create_essential(course: @maths_course, name: "Résolue"), status: "remediated")

        gaps = query.gaps

        assert_equal 5, gaps.size
        assert_equal({ name: "Fiche 0", course_name: "Maths Tle", students_count: 3 }, gaps.first)
        assert_equal 2, gaps.second[:students_count]
        assert_not_includes gaps.map { it[:name] }, "Résolue"
        assert_not_includes gaps.to_s, "Prénom"
      end

      test "the number of queries does not depend on the number of students, subjects or gaps" do
        count = ->(&block) { n = 0; counter = ->(*, payload) { n += 1 unless payload[:name] == "SCHEMA" }; ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block); n }
        student = create_student(classroom: @classroom)
        done(student, create_exercise(course: @maths_course), 80)
        few = count.call { query }

        4.times do
          other = create_student(classroom: @classroom)
          done(other, create_exercise(course: create_course(level: @level, material: create_material)), 60)
          create_gap(student: other)
        end

        assert_equal few, count.call { query }
      end
    end
  end
end
