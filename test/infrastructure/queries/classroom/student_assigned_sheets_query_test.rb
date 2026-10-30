require "test_helper"

module Queries
  module Classroom
    # prepare-interros-cahier, Lot F (CA-13, 14, 16 ; UDR feuilles-prepare-interros-et-devoirs §3, devoirs reçus) : « Ma classe » lit
    # les assignations actives de la classe principale de l'élève, groupées par envoi : une feuille par envoi, la plus récente d'abord.
    class StudentAssignedSheetsQueryTest < ActiveSupport::TestCase
      Actor = Entities::Identity::Actor

      setup do
        @course = create_course(name: "Thalès")
        @classroom = create_classroom(level: @course.level, series: @course.series, name: "3e 1")
        @student = create_student(classroom: @classroom)
        @teacher = create_teacher(classrooms: [ @classroom ])
        @thales = create_essential(course: @course, name: "La propriété de Thalès", position: 1, sheet: { "remember" => "Les rapports sont égaux." })
        @pythagore = create_essential(course: @course, name: "Pythagore", position: 2)
        @batches = 0
      end

      def sheets(student = @student) = StudentAssignedSheetsQuery.new.call(actor: Actor.new(user_id: student.id, role: :student))

      # Un envoi : les assignations d'un même batch_public_id, créées dans l'ordre des exercices.
      def send_batch(exercises, classroom: @classroom, at: Time.current)
        batch = format("BATCH%09d", @batches += 1)
        exercises.map { |exercise| create_assignment(classroom:, assignable: exercise, by: @teacher, batch_public_id: batch, assigned_at: at) }
      end

      def thales(count) = Array.new(count) { create_exercise(essential: @thales, questions: 1) }

      test "un envoi de 4 exercices est une feuille « Prépare devoirs » avec les notions mobilisées, sans doublon, dans l'ordre de l'envoi" do
        exercises = [ create_exercise(essential: @pythagore, questions: 1), create_exercise(essential: @thales, questions: 1),
                      create_exercise(essential: @pythagore, questions: 1), create_lesson_wide_exercise(course: @course, questions: 1) ]
        send_batch(exercises, at: Time.zone.local(2026, 10, 5, 9))

        sheet = sheets.sole

        assert_equal :devoirs, sheet.kind
        assert_equal exercises.map(&:public_id), sheet.exercises.map(&:public_id)
        assert_equal [ 1, 2, 3, 4 ], sheet.exercises.map(&:number)
        assert_equal [ "Pythagore", "La propriété de Thalès", "Thalès" ], sheet.notions
        assert_equal [ "Thalès" ], sheet.courses
        assert_equal Date.new(2026, 10, 5), sheet.assigned_on
      end

      test "un envoi de 1 ou 2 exercices est une feuille « Prépare interros », de 3 une feuille « Prépare devoirs »" do
        send_batch(thales(1), at: 3.hours.ago)
        send_batch(thales(2), at: 2.hours.ago)
        send_batch(thales(3), at: 1.hour.ago)

        assert_equal %i[devoirs interros interros], sheets.map(&:kind)
        assert_equal [ 3, 2, 1 ], sheets.map { it.exercises.size }
      end

      test "CA-14 : 2 exercices de la même notion portent son nom et son « À retenir » ; de notions différentes, aucun" do
        send_batch(thales(2), at: 1.hour.ago)
        send_batch([ create_exercise(essential: @thales, questions: 1), create_exercise(essential: @pythagore, questions: 1) ], at: 2.hours.ago)

        same, mixed = sheets

        assert_equal [ "La propriété de Thalès", "Les rapports sont égaux." ], [ same.notion, same.remember ]
        assert_nil mixed.notion
        assert_nil mixed.remember
        assert_equal [ "La propriété de Thalès", "Pythagore" ], mixed.notions
      end

      test "une notion commune sans « À retenir » n'en porte pas" do
        send_batch([ create_exercise(essential: @pythagore, questions: 1) ])

        sheet = sheets.sole

        assert_equal "Pythagore", sheet.notion
        assert_nil sheet.remember
      end

      test "un exercice de toute la leçon n'a pas de notion commune : sa leçon est nommée" do
        send_batch([ create_lesson_wide_exercise(course: @course, questions: 1) ])

        sheet = sheets.sole

        assert_nil sheet.notion
        assert_equal [ "Thalès" ], sheet.notions
      end

      test "un exercice assigné seul est un envoi d'un exercice ; la plus récente en haut" do
        old = create_assignment(classroom: @classroom, assignable: thales(1).first, by: @teacher, assigned_at: 2.days.ago)
        recent = send_batch(thales(3), at: 1.hour.ago)
        alone = create_assignment(classroom: @classroom, assignable: thales(1).first, by: @teacher, assigned_at: 1.minute.ago)

        found = sheets

        assert_equal [ [ alone.public_id ], recent.map(&:public_id), [ old.public_id ] ], found.map { it.hand_ins.values }
        assert_equal %i[interros devoirs interros], found.map(&:kind)
      end

      test "l'échéance de la feuille est la plus proche de ses exercices" do
        assignments = send_batch(thales(3), at: Time.zone.local(2026, 10, 5, 9))
        assignments.first.update!(due_on: Date.new(2026, 10, 9))
        assignments.last.update!(due_on: Date.new(2026, 10, 7))

        assert_equal Date.new(2026, 10, 7), sheets.sole.due_on
      end

      test "chaque exercice garde l'assignation à rendre" do
        exercises = thales(3)
        assignments = send_batch(exercises)

        sheet = sheets.sole

        assert_equal exercises.map(&:public_id).zip(assignments.map(&:public_id)).to_h, sheet.hand_ins
      end

      # CA-16 : avant de rendre, ni note ni correction, même si l'élève a déjà fait l'exercice pour s'entraîner.
      test "avant de rendre : aucune copie, aucune correction, même après une copie d'entraînement" do
        exercise = thales(1).first
        send_batch([ exercise ])
        practice = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 100)
        create_attempt(session: practice)

        shown = sheets.sole.exercises.sole

        assert_nil shown.copy
        assert_equal [ [ nil ] * 4 ], shown.questions.map { [ it.verdict, it.explanation, it.good_answer, it.response ] }
        assert_equal [ false ], shown.questions.flat_map(&:choices).map(&:picked).uniq
        assert_equal false, shown.due
      end

      test "après avoir rendu : la copie rendue, sa note et sa correction" do
        exercise = thales(1).first
        assignment = send_batch([ exercise ]).first
        handed = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 100,
                                         classroom_assignment_id: assignment.id)
        create_attempt(session: handed)

        shown = sheets.sole.exercises.sole

        assert_equal handed.public_id, shown.copy.session_public_id
        assert_equal true, shown.copy.passed
        assert_equal [ :correct ], shown.questions.map(&:verdict)
      end

      test "la copie d'un autre élève n'est jamais lue" do
        exercise = thales(1).first
        assignment = send_batch([ exercise ]).first
        other = create_student(classroom: @classroom)
        create_exercise_session(student: other, exercise:, status: "completed", classroom_assignment_id: assignment.id)

        assert_nil sheets.sole.exercises.sole.copy
      end

      # La sécurité du lot : un élève ne lit que la classe où il est.
      test "un élève d'une autre classe ne voit pas l'envoi, et voit le sien" do
        send_batch(thales(3))
        other_classroom = create_classroom(level: @course.level, series: @course.series, name: "3e 2")
        other = create_student(classroom: other_classroom)
        own = send_batch(thales(1), classroom: other_classroom)

        assert_equal [ own.map(&:public_id) ], sheets(other).map { it.hand_ins.values }
        assert_equal [ 3 ], sheets.map { it.exercises.size }
      end

      test "un élève qui a quitté sa classe, ou sans classe, ne voit rien" do
        send_batch(thales(3))
        Orm::ClassroomStudent.where(student_id: @student.id).update_all(left_at: Time.current)

        assert_empty sheets
        assert_empty sheets(create_student)
      end

      test "ni l'assignation retirée, ni l'exercice archivé ou non publié n'apparaissent ; un envoi vidé disparaît" do
        kept, withdrawn, archived, draft = thales(4)
        send_batch([ kept, withdrawn ])[1].update!(status: "archived", archived_at: Time.current, archived_by: @teacher)
        send_batch([ archived ])
        send_batch([ draft ])
        archived.update!(status: "archived", archived_at: Time.current)
        draft.update!(status: "draft")

        assert_equal [ [ kept.public_id ] ], sheets.map { |sheet| sheet.exercises.map(&:public_id) }
      end

      test "un exercice d'une notion non publiée ou d'un cours d'un autre niveau n'apparaît pas" do
        hidden = create_exercise(essential: create_essential(course: @course, name: "Brouillon", status: "draft"), questions: 1)
        other_level = create_exercise(essential: create_essential(course: create_course(level: create_level(name: "Tle"))), questions: 1)
        send_batch([ hidden, other_level ])

        assert_empty sheets
      end

      test "un envoi de deux leçons : les deux sont nommées, chaque exercice est lu" do
        other = create_course(name: "Fonctions", level: @course.level, series: @course.series)
        send_batch([ create_exercise(essential: @thales, questions: 1), create_exercise(essential: create_essential(course: other), questions: 1),
                     create_exercise(essential: @thales, questions: 1) ])

        sheet = sheets.sole

        assert_equal %w[Thalès Fonctions], sheet.courses
        assert_equal 3, sheet.exercises.size
      end
    end
  end
end
