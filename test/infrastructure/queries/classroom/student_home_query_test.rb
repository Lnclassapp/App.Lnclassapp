require "test_helper"

module Queries
  module Classroom
    # CL-23, TR-04, AS-36: the student home reads the primary classroom only, and lists the exercises assigned to it when
    # they and their parents are published (ADR-0072 §4.1: an exercise is assigned directly, never through its sheet or
    # course). The old feed raised NameError as soon as the student had a classroom.
    class StudentHomeQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school(name: "Lycée Classique")
        @classroom = create_classroom(school: @school, level: create_level(name: "Tle"), name: "Tle D 1", join_code: "kfm37")
        @student = create_student(classroom: @classroom)
        @svt = create_material(name: "SVT", category: "science")
        # UDR-0013, amendement du 2026-10-01 : la classe de l'élève est du niveau du cours.
        @course = create_course(material: @svt, name: "Génétique", level: @classroom.level)
        @essential = create_essential(course: @course, name: "La méiose")
      end

      def home(student = @student) = StudentHomeQuery.new.call(student_id: student.id)
      def titles(row = home) = row.assigned_exercises.map(&:title)

      test "the header of the primary classroom, its code in capitals and its active headcount" do
        create_student(classroom: @classroom)
        gone = create_student(classroom: @classroom)
        Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
        secondary = create_user(role: "student")
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom: @classroom, student: secondary, primary: false, joined_at: Time.current)

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

      # UDR-0013, amendement du 2026-10-01 : l'accueil ne liste que ce que l'élève peut ouvrir. Une assignation, une session
      # terminée ou une lacune hors de son niveau, antérieures à la règle, n'y apparaissent plus.
      test "an exercise, a completed session and a sheet to review of another level are left out" do
        other_course = create_course(level: create_level)
        other_essential = create_essential(course: other_course)
        other = create_exercise(essential: other_essential, title: "Autre niveau")
        own = create_exercise(essential: @essential, title: "Mon niveau")
        [ other, own ].each { create_assignment(classroom: @classroom, assignable: it) }
        create_exercise_session(student: @student, exercise: other, status: "completed", score_percent: 80)
        create_exercise_session(student: @student, exercise: own, status: "completed", score_percent: 60)
        create_gap(student: @student, essential: other_essential)
        create_gap(student: @student, essential: @essential)

        row = home

        assert_equal [ "Mon niveau" ], titles(row)
        # create_gap ouvre aussi une session terminée, sur un exercice de sa fiche : seule celle d'un autre niveau disparaît.
        assert_includes row.recent_sessions.map(&:exercise_title), "Mon niveau"
        assert_not_includes row.recent_sessions.map(&:exercise_title), "Autre niveau"
        assert_equal [ @essential.slug ], row.pending_gaps.map(&:essential_slug)
      end

      test "the exercises assigned directly, the most recently assigned first; their sheet and course assign nothing else" do
        direct = create_exercise(essential: create_essential(course: create_course(level: @classroom.level)), title: "Direct")
        older = create_exercise(essential: @essential, title: "Plus ancien")
        create_exercise(essential: @essential, title: "Même fiche, non assigné")
        create_exercise(essential: create_essential(course: @course), title: "Même cours, non assigné")
        create_assignment(classroom: @classroom, assignable: older, assigned_at: 2.days.ago)
        create_assignment(classroom: @classroom, assignable: direct, assigned_at: 1.day.ago)

        row = home

        assert_equal [ "Direct", "Plus ancien" ], titles(row)
        assert_equal [ direct.public_id, older.public_id ], row.assigned_exercises.map(&:public_id)
        assert_equal [ "SVT", "science" ], row.assigned_exercises.last.to_h.values_at(:material_name, :material_category)
      end

      # UDR-0062 §3.2, PRD « Accueil élève » : the list of « À faire » sorts by due date, the exercises without one after.
      test "the order of « À faire »: due the 8th, due the 12th, then without a due date, a started exercise in its place" do
        travel_to Time.zone.local(2026, 10, 6, 10) do
          undated = create_exercise(essential: @essential, title: "Sans échéance")
          later = create_exercise(essential: @essential, title: "Dû le 12")
          sooner = create_exercise(essential: @essential, title: "Dû le 8, commencé")
          create_assignment(classroom: @classroom, assignable: undated, assigned_at: 1.day.ago)
          create_assignment(classroom: @classroom, assignable: later, assigned_at: 1.hour.ago, due_on: Date.new(2026, 10, 12))
          create_assignment(classroom: @classroom, assignable: sooner, assigned_at: 4.days.ago, due_on: Date.new(2026, 10, 8))
          create_exercise_session(student: @student, exercise: sooner)

          exercises = home.assigned_exercises

          assert_equal [ "Dû le 8, commencé", "Dû le 12", "Sans échéance" ], exercises.map(&:title)
          assert_equal [ Date.new(2026, 10, 8), Date.new(2026, 10, 12), nil ], exercises.map(&:due_on)
        end
      end

      # UDR-0062 §3.2, charte §8: being started is not a sort key; neither is being assigned more recently, before the date.
      test "a started exercise due the 12th does not pass an exercise not started due the 8th" do
        travel_to Time.zone.local(2026, 10, 6, 10) do
          started = create_exercise(essential: @essential, title: "Dû le 12, commencé")
          sooner = create_exercise(essential: @essential, title: "Dû le 8, non commencé")
          create_assignment(classroom: @classroom, assignable: started, assigned_at: 1.hour.ago, due_on: Date.new(2026, 10, 12))
          create_assignment(classroom: @classroom, assignable: sooner, assigned_at: 4.days.ago, due_on: Date.new(2026, 10, 8))
          session = create_exercise_session(student: @student, exercise: started)

          exercises = home.assigned_exercises

          assert_equal [ "Dû le 8, non commencé", "Dû le 12, commencé" ], exercises.map(&:title)
          assert_equal [ nil, session.public_id ], exercises.map(&:started_session_public_id)
          assert_equal [ 0, 0 ], exercises.map(&:completed_count)
        end
      end

      test "on the same due date, or without one, the most recently assigned first" do
        travel_to Time.zone.local(2026, 10, 6, 10) do
          due_on = Date.new(2026, 10, 8)
          { "Dû, ancien" => [ 3.days.ago, due_on ], "Dû, récent" => [ 1.day.ago, due_on ],
            "Sans, ancien" => [ 3.days.ago, nil ], "Sans, récent" => [ 1.day.ago, nil ] }.each do |title, (assigned_at, due)|
            create_assignment(classroom: @classroom, assignable: create_exercise(essential: @essential, title:), assigned_at:, due_on: due)
          end

          assert_equal [ "Dû, récent", "Dû, ancien", "Sans, récent", "Sans, ancien" ], titles
        end
      end

      # UDR-0062 §3.2 : un exercice terminé passe en fin de liste ; la vue n'en dit plus la date (due_badge, done:).
      test "a completed exercise goes after the ones not completed, even when it was due first" do
        travel_to Time.zone.local(2026, 10, 6, 10) do
          done = create_exercise(essential: @essential, title: "Terminé, dû hier")
          undated = create_exercise(essential: @essential, title: "Sans échéance")
          create_assignment(classroom: @classroom, assignable: done, assigned_at: 3.days.ago, due_on: Date.new(2026, 10, 5))
          create_assignment(classroom: @classroom, assignable: undated, assigned_at: 4.days.ago)
          create_exercise_session(student: @student, exercise: done, status: "completed", score_percent: 70)

          exercises = home.assigned_exercises

          assert_equal [ "Sans échéance", "Terminé, dû hier" ], exercises.map(&:title)
          assert_equal [ 0, 1 ], exercises.map(&:completed_count)
        end
      end

      # UDR-0062 §3.3, ADR-0072 §4.4 : en retard pour l'élève = non terminé et échéance passée ; jamais sans échéance.
      test "the subjects with an exercise late for the student, for the phone family" do
        travel_to Time.zone.local(2026, 10, 9, 10) do
          maths, french, history = [ %w[Maths science], %w[Français literature], %w[Histoire literature] ].map do |name, category|
            create_material(name:, category:)
          end
          late, done_late, due_today = [ maths, french, history ].map do |material|
            create_exercise(essential: create_essential(course: create_course(material:, level: @classroom.level)))
          end
          [ late, done_late ].each do |exercise|
            create_assignment(classroom: @classroom, assignable: exercise, assigned_at: 5.days.ago, due_on: Date.new(2026, 10, 8))
          end
          create_assignment(classroom: @classroom, assignable: due_today, assigned_at: 1.day.ago, due_on: Date.new(2026, 10, 9))
          create_assignment(classroom: @classroom, assignable: create_exercise(essential: @essential), assigned_at: 9.days.ago)
          create_exercise_session(student: @student, exercise: done_late, status: "completed", score_percent: 90)

          assert_equal [ maths.slug ], home.late_material_slugs
        end
      end

      test "a withdrawn assignment, an archived or draft exercise, or an unpublished parent: absent" do
        create_assignment(classroom: @classroom, assignable: create_exercise(essential: @essential, title: "Brouillon", status: "draft"))
        create_assignment(classroom: @classroom, assignable: create_exercise(essential: @essential, title: "Archivé", status: "archived"))
        withdrawn = create_exercise(essential: @essential, title: "Retiré")
        create_assignment(classroom: @classroom, assignable: withdrawn, status: "archived")
        draft_sheet = create_essential(course: @course, status: "draft")
        create_assignment(classroom: @classroom, assignable: create_exercise(essential: draft_sheet, title: "Fiche brouillon"))
        archived_course = create_course(status: "archived", level: @classroom.level)
        create_assignment(classroom: @classroom,
                          assignable: create_exercise(essential: create_essential(course: archived_course), title: "Cours archivé"))

        assert_empty titles
      end

      test "the primary classroom only" do
        other = create_classroom
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom: other, student: @student, primary: false, joined_at: Time.current)
        create_assignment(classroom: other, assignable: create_exercise(essential: @essential, title: "Autre classe"))

        assert_empty titles
      end

      test "the progress of the student: best score, completed sessions, badge and the session to resume" do
        exercise = create_exercise(essential: @essential)
        untouched = create_exercise(essential: @essential)
        # Assignés au même instant ; le terminé passe après celui qui ne l'est pas (UDR-0062 §3.2).
        at = 1.hour.ago
        [ exercise, untouched ].each { create_assignment(classroom: @classroom, assignable: it, assigned_at: at) }
        create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 40)
        best = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 80)
        create_exercise_session(student: @student, exercise:, status: "abandoned")
        started = create_exercise_session(student: @student, exercise:)
        create_badge(student: @student, exercise:, level: "gold", session: best)
        create_exercise_session(exercise:, status: "completed", score_percent: 100)

        fresh, progress = home.assigned_exercises

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

      # UDR-0076 §3.1: the subjects with a published course of the student's level, once each, in the charter order
      # (Mathématiques, Physique-Chimie, SVT, Français, Histoire-Géographie, EDHC, Philosophie), then the others by name.
      test "the subjects of the student's level, published courses only, once each, in the charter order" do
        level = @classroom.level
        create_course(material: @svt, level:)
        create_course(material: create_material(name: "Anglais", category: "literature"), level:)
        create_course(material: create_material(name: "Mathématiques"), level:)
        create_course(material: create_material(name: "Physique-Chimie"), level:, status: "draft")
        create_course(material: create_material(name: "Français", category: "literature"), level: create_level)

        assert_equal [ %w[mathematiques Mathématiques], %w[svt SVT], %w[anglais Anglais] ],
                     home.subjects.map { [ it.slug, it.name ] }
      end

      test "a student of another series sees no subject of a course reserved to a series" do
        series = create_series(name: "D")
        create_course(material: create_material(name: "Mathématiques"), level: @classroom.level, series:)

        assert_equal %w[svt], home.subjects.map(&:slug)
      end

      test "an empty home" do
        row = home

        assert_equal [ [], [], [], [] ], row.to_h.values_at(:assigned_exercises, :recent_sessions, :pending_gaps, :late_material_slugs)
        assert_equal %w[svt], row.subjects.map(&:slug)
      end

      # IL-14, IL-17 (UDR-0079 §3.5): a student without an active classroom chooses one, the DRENA and the school of their
      # last primary classroom already chosen; a removal of less than 7 days ago says why they have no classroom.
      def last(student, now: Time.current) = StudentHomeQuery.new.last_classroom(student_id: student.id, now:)

      def remove(student, classroom, at:)
        Orm::ClassroomStudent.where(student:, classroom:).update_all(left_at: at, removed_at: at, removed_by_id: create_teacher.id)
      end

      test "IL-17: the DRENA and the school of the archived primary classroom, without a removal" do
        drena = create_drena
        archived = create_classroom(school: create_school(drena:), status: "archived")
        student = create_student(classroom: archived)

        row = last(student)

        assert_equal [ drena.public_id, archived.school.public_id, nil ],
                     row.to_h.values_at(:drena_public_id, :school_public_id, :recent_removal_at)
      end

      test "IL-14: the classroom the student was removed from, and the time of a removal under 7 days old" do
        freeze_time do
          remove(@student, @classroom, at: 2.days.ago)

          row = last(@student)

          assert_equal [ @school.drena.public_id, @school.public_id, 2.days.ago ],
                       row.to_h.values_at(:drena_public_id, :school_public_id, :recent_removal_at)
          assert_equal 2.days.ago, last(@student, now: 7.days.from_now - 2.days).recent_removal_at
          assert_nil last(@student, now: 7.days.from_now - 2.days + 1.second).recent_removal_at
        end
      end

      test "the last primary classroom: an open one (archived) first, then the most recently left; secondary ones ignored" do
        earlier = create_classroom(school: create_school)
        later = create_classroom(school: create_school)
        student = create_student(classroom: earlier, joined_at: 2.years.ago)
        Orm::ClassroomStudent.where(student:, classroom: earlier).update_all(left_at: 1.year.ago)
        Orm::ClassroomStudent.create!(classroom: later, student:, primary: true, joined_at: 1.year.ago, joined_via: "standard")
        remove(student, later, at: 1.day.ago)
        Orm::ClassroomStudent.create!(classroom: create_classroom, student:, primary: false, joined_at: 1.hour.ago,
                                      joined_via: "standard")

        assert_equal later.school.public_id, last(student).school_public_id

        archived = create_classroom(status: "archived")
        Orm::ClassroomStudent.create!(classroom: archived, student:, primary: true, joined_at: 1.hour.ago, joined_via: "standard")

        row = last(student)

        assert_equal [ archived.school.public_id, nil ], row.to_h.values_at(:school_public_id, :recent_removal_at)
      end

      test "a removal followed by a departure elsewhere is not recent news; a student who never had a classroom: nothing" do
        remove(@student, @classroom, at: 3.days.ago)
        other = create_classroom(status: "archived")
        Orm::ClassroomStudent.create!(classroom: other, student: @student, primary: true, joined_at: 2.days.ago, joined_via: "link")

        assert_nil last(@student).recent_removal_at
        assert_equal [ nil, nil, nil ], last(create_student).to_h.values
      end
    end
  end
end
