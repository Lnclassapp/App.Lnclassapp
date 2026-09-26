require "test_helper"

module Queries
  module Classroom
    # CL-23, TR-04, AS-36: the student home reads the primary classroom only, and lists the exercises assigned to it,
    # directly or through their sheet or course, when they and their parents are published. The old feed raised
    # NameError as soon as the student had a classroom.
    class StudentHomeQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school(name: "Lycée Classique")
        @classroom = create_classroom(school: @school, level: create_level(name: "Tle"), name: "Tle D 1", join_code: "kfm37")
        @student = create_student(classroom: @classroom)
        @svt = create_material(name: "SVT", category: "science")
        @course = create_course(material: @svt, name: "Génétique")
        @essential = create_essential(course: @course, name: "La méiose")
      end

      def home(student = @student) = StudentHomeQuery.new.call(student_id: student.id)
      def titles(row = home) = row.assigned_exercises.map(&:title)

      test "the header of the primary classroom, its code in capitals and its active headcount" do
        create_student(classroom: @classroom)
        gone = create_student(classroom: @classroom)
        Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
        secondary = create_user(role: "student")
        Orm::ClassroomStudent.create!(classroom: @classroom, student: secondary, primary: false, joined_at: Time.current)

        row = home

        assert_equal [ "Lycée Classique", "Tle", "Tle D 1", "KFM37", 3 ],
                     row.to_h.values_at(:school_name, :level_name, :classroom_name, :join_code_display, :classmates_count)
      end

      test "no active primary classroom: nil" do
        assert_nil home(create_student)
        assert_nil home(create_student(classroom: create_classroom(status: "archived")))

        left = create_student(classroom: @classroom)
        Orm::ClassroomStudent.where(student: left).update_all(left_at: Time.current)
        assert_nil home(left)
      end

      test "exercises assigned directly, by their sheet or by their course, each once" do
        direct = create_exercise(essential: create_essential(course: create_course), title: "Direct")
        by_sheet = create_exercise(essential: @essential, title: "Par la fiche")
        by_course = create_exercise(essential: create_essential(course: @course), title: "Par le cours")
        create_assignment(classroom: @classroom, assignable: @course, assigned_at: 3.days.ago)
        create_assignment(classroom: @classroom, assignable: @essential, assigned_at: 2.days.ago)
        create_assignment(classroom: @classroom, assignable: direct, assigned_at: 1.day.ago)

        row = home

        assert_equal [ "Direct", "Par la fiche", "Par le cours" ], titles(row)
        assert_equal [ direct.public_id, by_sheet.public_id, by_course.public_id ], row.assigned_exercises.map(&:public_id)
        assert_equal [ "SVT", "science" ], row.assigned_exercises.last.to_h.values_at(:material_name, :material_category)
      end

      test "a withdrawn assignment, an archived or draft exercise, or an unpublished parent: absent" do
        create_exercise(essential: @essential, title: "Brouillon", status: "draft")
        create_exercise(essential: @essential, title: "Archivé", status: "archived")
        create_assignment(classroom: @classroom, assignable: @essential)
        withdrawn = create_exercise(title: "Retiré")
        create_assignment(classroom: @classroom, assignable: withdrawn, status: "archived")
        draft_sheet = create_essential(course: @course, status: "draft")
        create_exercise(essential: draft_sheet, title: "Fiche brouillon")
        create_assignment(classroom: @classroom, assignable: draft_sheet)
        archived_course = create_course(status: "archived")
        create_exercise(essential: create_essential(course: archived_course), title: "Cours archivé")
        create_assignment(classroom: @classroom, assignable: archived_course)

        assert_empty titles
      end

      test "the primary classroom only" do
        other = create_classroom
        Orm::ClassroomStudent.create!(classroom: other, student: @student, primary: false, joined_at: Time.current)
        create_assignment(classroom: other, assignable: create_exercise(essential: @essential, title: "Autre classe"))

        assert_empty titles
      end

      test "the progress of the student: best score, completed sessions, badge and the session to resume" do
        exercise = create_exercise(essential: @essential)
        untouched = create_exercise(essential: @essential)
        create_assignment(classroom: @classroom, assignable: @essential)
        create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 40)
        best = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 80)
        create_exercise_session(student: @student, exercise:, status: "abandoned")
        started = create_exercise_session(student: @student, exercise:)
        create_badge(student: @student, exercise:, level: "gold", session: best)
        create_exercise_session(exercise:, status: "completed", score_percent: 100)

        progress, fresh = home.assigned_exercises

        assert_equal [ 80, 2, "gold", started.public_id ],
                     progress.to_h.values_at(:best_score_percent, :completed_count, :badge_level, :started_session_public_id)
        assert_equal untouched.public_id, fresh.public_id
        assert_equal [ nil, 0, nil, nil ],
                     fresh.to_h.values_at(:best_score_percent, :completed_count, :badge_level, :started_session_public_id)
      end

      test "the 10 last completed sessions, newest first, with their score" do
        exercise = create_exercise(essential: @essential, title: "Méiose")
        11.times do |index|
          create_exercise_session(student: @student, exercise:, status: "completed", score_percent: index * 5,
                                  completed_at: (20 - index).hours.ago)
        end
        create_exercise_session(student: @student, exercise:)
        create_exercise_session(exercise:, status: "completed")

        sessions = home.recent_sessions

        assert_equal 10, sessions.size
        assert_equal (1..10).map { it * 5 }.reverse, sessions.map(&:score_percent)
        assert_equal [ "Méiose" ], sessions.map(&:exercise_title).uniq
        assert_equal Orm::ExerciseSession.find_by(score_percent: 50, student: @student).public_id, sessions.first.public_id
        assert_equal sessions, StudentHomeQuery.new.recent_sessions(student_id: @student.id)
        assert_empty StudentHomeQuery.new.recent_sessions(student_id: create_student.id)
      end

      test "the pending gaps of the student, with their published sheet" do
        create_gap(student: @student, essential: @essential)
        create_gap(student: @student, essential: create_essential(course: @course), status: "remediated")
        create_gap(student: @student, essential: create_essential(course: @course, status: "archived"))
        create_gap(essential: @essential)

        assert_equal [ [ "La méiose", @essential.slug, @course.slug ] ],
                     home.pending_gaps.map { it.to_h.values_at(:essential_name, :essential_slug, :course_slug) }
      end

      test "an empty home" do
        row = home

        assert_equal [ [], [], [] ], row.to_h.values_at(:assigned_exercises, :recent_sessions, :pending_gaps)
      end
    end
  end
end
