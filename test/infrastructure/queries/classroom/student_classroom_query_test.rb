require "test_helper"

module Queries
  module Classroom
    # CL-22 (CS#B13): « Ma classe » reads the primary classroom only. UDR-0076 §3.2: a course is no longer assigned
    # (ADR-0072), the « assigned courses » are the courses of the exercises assigned to the classroom; then the assigned
    # exercises not done yet, and every exercise the student completed, with their best score.
    class StudentClassroomQueryTest < ActiveSupport::TestCase
      setup do
        @classroom = create_classroom(school: create_school(name: "Lycée Classique"), level: create_level(name: "Tle"),
                                      series: create_series(name: "D"), name: "Tle D 1", school_year: "2026-2027")
        @student = create_student(classroom: @classroom)
        @svt = create_material(name: "SVT", category: "science")
        @course = create_course(material: @svt, name: "Génétique", level: @classroom.level)
        @essential = create_essential(course: @course)
      end

      def exercise(title, essential: @essential) = create_exercise(essential:, title:)

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end

      def classroom(student = @student) = StudentClassroomQuery.new.call(student_id: student.id)

      test "the header of the primary classroom, and no roster" do
        create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yapo")

        row = classroom

        assert_equal [ @classroom.public_id, "Tle D 1", "Tle", "D", "Lycée Classique", "2026-2027" ],
                     row.to_h.values_at(:public_id, :classroom_name, :level_name, :series_name, :school_name, :school_year)
        assert_equal %i[public_id classroom_name level_name series_name school_name school_year courses assigned_exercises
                        treated_exercises], row.to_h.keys
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

      # CA-4: the courses of the assigned exercises, once each, the most recently assigned first, with their count of
      # assigned exercises; a course without an assigned exercise, an archived assignment or a draft course are left out.
      test "the assigned courses are the courses of the exercises assigned to the classroom, newest first" do
        maths = create_course(material: create_material(name: "Mathématiques"), name: "Fonctions", level: @classroom.level)
        create_assignment(classroom: @classroom, assignable: exercise("Méiose"), assigned_at: 3.hours.ago)
        create_assignment(classroom: @classroom, assignable: exercise("Mitose"), assigned_at: 2.hours.ago)
        create_assignment(classroom: @classroom, assignable: exercise("Dérivées", essential: create_essential(course: maths)),
                          assigned_at: 1.hour.ago)
        create_course(material: @svt, name: "Sans exercice assigné", level: @classroom.level)
        withdrawn = create_course(material: @svt, name: "Retiré", level: @classroom.level)
        create_assignment(classroom: @classroom, assignable: exercise("Retiré", essential: create_essential(course: withdrawn)),
                          status: "archived")
        draft = create_course(material: @svt, name: "Brouillon", level: @classroom.level, status: "draft")
        create_assignment(classroom: @classroom, assignable: exercise("Brouillon", essential: create_essential(course: draft)))

        assert_equal [ [ maths.slug, "Fonctions", "mathematiques", 1 ], [ @course.slug, "Génétique", "svt", 2 ] ],
                     classroom.courses.map { it.to_h.values_at(:slug, :name, :material_slug, :assigned_count) }
      end

      # CA-5: the assigned exercises in the order of « À faire », without the ones already done.
      test "the assigned exercises not done yet, in the order of « À faire »" do
        done = exercise("Déjà fait")
        create_assignment(classroom: @classroom, assignable: done, assigned_at: 1.minute.ago)
        create_exercise_session(student: @student, exercise: done, status: "completed", score_percent: 50)
        create_assignment(classroom: @classroom, assignable: exercise("Ancien"), assigned_at: 2.hours.ago)
        create_assignment(classroom: @classroom, assignable: exercise("Récent"), assigned_at: 1.hour.ago)
        create_assignment(classroom: create_classroom, assignable: exercise("Autre classe"))

        assert_equal %w[Récent Ancien], classroom.assigned_exercises.map(&:title)
      end

      # CA-6: one line per completed exercise, with its best score and its last session, the most recently completed first;
      # a session started, abandoned, of another student or of another level is left out.
      test "the treated exercises: the best score, the last session, the most recently completed first" do
        twice = exercise("Refait")
        first = create_exercise_session(student: @student, exercise: twice, status: "completed", score_percent: 80)
        first.update!(completed_at: 3.hours.ago)
        last = create_exercise_session(student: @student, exercise: twice, status: "completed", score_percent: 40)
        last.update!(completed_at: 1.hour.ago)
        once = exercise("Une fois")
        create_exercise_session(student: @student, exercise: once, status: "completed", score_percent: 65)
                               .update!(completed_at: 2.hours.ago)
        create_exercise_session(student: @student, exercise: exercise("Commencé"))
        create_exercise_session(student: @student, exercise: exercise("Abandonné"), status: "abandoned")
        create_exercise_session(exercise: exercise("Autre élève"), status: "completed", score_percent: 100)
        elsewhere = create_exercise(essential: create_essential(course: create_course(level: create_level)), title: "Autre niveau")
        create_exercise_session(student: @student, exercise: elsewhere, status: "completed", score_percent: 90)

        rows = classroom.treated_exercises

        assert_equal [ [ "Refait", 80 ], [ "Une fois", 65 ] ], rows.map { [ it.title, it.best_score_percent ] }
        assert_equal [ last.public_id, twice.public_id, "SVT", "science" ],
                     rows.first.to_h.values_at(:last_session_public_id, :exercise_public_id, :material_name, :material_category)
      end

      # UDR-0076 §3.2 : le travail terminé reste à l'élève quand l'exercice est dépublié ensuite, comme « Mes activités
      # récentes » de l'accueil ; son résultat reste ouvert par ReadSessionPolicy.
      test "a treated exercise unpublished afterwards stays in the treated exercises" do
        archived = exercise("Archivé ensuite")
        create_exercise_session(student: @student, exercise: archived, status: "completed", score_percent: 60)
        archived.update!(status: "archived", archived_at: Time.current)

        assert_equal [ "Archivé ensuite" ], classroom.treated_exercises.map(&:title)
      end

      test "nothing assigned, nothing treated: three empty lists" do
        assert_equal [ [], [], [] ], classroom.to_h.values_at(:courses, :assigned_exercises, :treated_exercises)
      end

      # ADR-0067: a fixed number of queries, whatever the number of courses, exercises and sessions.
      test "the same number of queries with one exercise or with five" do
        add = lambda do |title|
          assigned = exercise(title, essential: create_essential(course: create_course(material: @svt, level: @classroom.level)))
          create_assignment(classroom: @classroom, assignable: assigned)
          create_exercise_session(student: @student, exercise: exercise("#{title} fait"), status: "completed", score_percent: 70)
        end
        add.call("E0")
        classroom
        one = count_queries { classroom }
        4.times { add.call("E#{it + 1}") }

        assert_equal one, count_queries { classroom }
        assert_equal [ 5, 5, 5 ], classroom.to_h.values_at(:courses, :assigned_exercises, :treated_exercises).map(&:size)
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
