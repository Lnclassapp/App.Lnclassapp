require "test_helper"

module Queries
  module Classroom
    # Chantier activation-eleve, PRD §4 CA-1 à CA-7 (UDR-0174 §2) : tant que l'élève n'a réussi
    # aucun exercice (une copie terminée à 10/20 arrondi), l'accueil lui propose son premier exercice : la copie en cours,
    # sinon le devoir de sa classe s'il y est entré par le lien ou le code, sinon le programme, matière par matière.
    class ActivationQueryTest < ActiveSupport::TestCase
      setup do
        @level = create_level(name: "3e")
        @classroom = create_classroom(level: @level)
        @maths = create_material(name: "Mathématiques")
        @pc = create_material(name: "Physique-Chimie")
        @angles = create_course(level: @level, material: @maths, name: "Les angles", subtitle: "Leçon 1")
        @circuits = create_course(level: @level, material: @pc, name: "Les circuits", subtitle: "Leçon 1")
        @first = create_lesson_wide_exercise(course: @angles, title: "Mesurer un angle")
        @second = create_lesson_wide_exercise(course: @angles, title: "Angles opposés")
        @physics = create_lesson_wide_exercise(course: @circuits, title: "Le circuit simple")
      end

      def student(joined_via: "standard") = create_student(classroom: @classroom, joined_via:)
      def home(learner) = StudentHomeQuery.new.call(student_id: learner.id)
      def call(learner) = ActivationQuery.new.call(student_id: learner.id, home: home(learner))
      def finish(learner, exercise, score) = create_exercise_session(student: learner, exercise:, status: "completed", score_percent: score,
                                                                     completed_at: Time.current)

      # Chantier entree-et-accueil-eleve-allegees, CA-14 : la fenêtre s'arrête à la première copie rendue, quelle qu'en soit la note.
      test "a copy handed in, whatever the mark, counts; a copy started or abandoned does not" do
        learner = student
        create_exercise_session(student: learner, exercise: @first, status: "abandoned")
        create_exercise_session(student: learner, exercise: @second, answered_count: 1)
        assert_not ActivationQuery.new.submitted_copy?(student_id: learner.id)

        finish(learner, @physics, 0)
        assert ActivationQuery.new.submitted_copy?(student_id: learner.id)
      end

      test "CA-1: no copy at all: the first exercise of the first subject, in the program order, to start" do
        row = call(student)

        assert_equal [ :start, @first.public_id, "Mesurer un angle", "Les angles", "Mathématiques", nil, nil, false ],
                     row.to_h.values_at(:kind, :exercise_public_id, :title, :lesson_name, :material_name, :session_public_id,
                                        :resume_number, :assigned)
      end

      test "CA-2: a copy in progress of his level is resumed at the question after his answers; the most recent wins" do
        learner = student
        create_exercise_session(student: learner, exercise: @first, started_at: 2.days.ago, answered_count: 1)
        recent = create_exercise_session(student: learner, exercise: @physics, started_at: 1.hour.ago, answered_count: 1)

        row = call(learner)

        assert_equal [ :resume, @physics.public_id, recent.public_id, 2, "Physique-Chimie", "Les circuits", false ],
                     row.to_h.values_at(:kind, :exercise_public_id, :session_public_id, :resume_number, :material_name, :lesson_name, :assigned)
        assert_equal recent.public_id, ActivationQuery.new.resume(student_id: learner.id).session_public_id
      end

      test "CA-2: a copy in progress of another level, or of an unpublished exercise, is not resumed" do
        learner = student
        create_exercise_session(student: learner, exercise: create_lesson_wide_exercise(course: create_course(level: create_level)))
        draft = create_lesson_wide_exercise(course: @angles, title: "Brouillon")
        create_exercise_session(student: learner, exercise: draft)
        draft.update_columns(status: "draft")

        assert_equal [ :start, @first.public_id ], call(learner).to_h.values_at(:kind, :exercise_public_id)
      end

      test "CA-3: brought by the link or the code of his class, an open assignment is proposed, marked as given by the class" do
        %w[link code].each do |via|
          learner = student(joined_via: via)
          create_assignment(classroom: @classroom, assignable: @physics) if via == "link"

          row = call(learner)

          assert_equal [ :start, @physics.public_id, "Le circuit simple", "Physique-Chimie", nil, true ],
                       row.to_h.values_at(:kind, :exercise_public_id, :title, :material_name, :lesson_name, :assigned), via
        end
      end

      test "CA-3: brought by his class without an open assignment: the program, as for the student alone" do
        learner = student(joined_via: "code")
        create_assignment(classroom: @classroom, assignable: @physics)
        finish(learner, @physics, 20)

        assert_equal [ @first.public_id, false ], call(learner).to_h.values_at(:exercise_public_id, :assigned)
      end

      test "CA-4: alone (the list), his class's assignment stays in « À faire »; the card is the program" do
        create_assignment(classroom: @classroom, assignable: @physics)

        assert_equal [ @first.public_id, false ], call(student).to_h.values_at(:exercise_public_id, :assigned)
      end

      test "CA-5: a completed copy at 10/20 rounded activates the student: no card" do
        learner = student
        finish(learner, @physics, 48)

        assert ActivationQuery.new.activated?(student_id: learner.id)
        assert_nil call(learner)
        assert_nil ActivationQuery.new.resume_session_public_id(student_id: learner.id)
      end

      test "CA-6: completed copies all under 10/20: not activated; the next exercise after the last completed one" do
        learner = student
        finish(learner, @first, 47)

        assert_not ActivationQuery.new.activated?(student_id: learner.id)
        assert_equal @second.public_id, call(learner).exercise_public_id
      end

      test "CA-6: a copy in progress is the card's, unless the student is activated" do
        learner = student
        copy = create_exercise_session(student: learner, exercise: @second)

        assert_equal copy.public_id, ActivationQuery.new.resume_session_public_id(student_id: learner.id)
      end

      test "CA-6: no copy in progress: nothing for the card to resume" do
        learner = student

        assert_nil ActivationQuery.new.resume_session_public_id(student_id: learner.id)
      end

      test "CA-7: a level without a published exercise: no card; a subject without exercise is skipped" do
        empty = create_classroom(level: create_level)
        create_course(level: empty.level, material: @maths)

        assert_nil call(create_student(classroom: empty))

        [ @first, @second ].each { it.update_columns(status: "draft") }
        assert_equal @physics.public_id, call(student).exercise_public_id
      end

      test "CA-2: a copy in progress of an archived exercise, or in an unpublished lesson, is not resumed" do
        learner = student
        create_exercise_session(student: learner, exercise: @second)
        @second.update_columns(archived_at: Time.current)
        create_exercise_session(student: learner, exercise: @physics)
        @circuits.update_columns(status: "draft")

        assert_nil ActivationQuery.new.resume(student_id: learner.id)
      end

      test "CA-3: the first open assignment in the order of « À faire » wins; an assignment already started is left to the resume" do
        learner = student(joined_via: "link")
        create_assignment(classroom: @classroom, assignable: @second, due_on: Date.current + 3, assigned_at: 1.day.ago)
        create_assignment(classroom: @classroom, assignable: @physics, due_on: Date.current + 1, assigned_at: 1.day.ago)

        assert_equal @physics.public_id, call(learner).exercise_public_id

        home = home(learner)
        started = home.assigned_exercises.map { it.public_id == @physics.public_id ? it.with(started_session_public_id: "x") : it }
        row = ActivationQuery.new.call(student_id: learner.id, home: home.with(assigned_exercises: started))
        assert_equal [ @second.public_id, true ], row.to_h.values_at(:exercise_public_id, :assigned)
      end
    end
  end
end
