require "test_helper"

module Queries
  module Catalog
    # UDR page de la leçon §3.4 : exercices publiés groupés par notion (ordre des notions) puis « Toute la leçon » ; état de l'élève
    # (lacune > assignation non rendue > meilleure note) ; statut de l'équipe ; cibles de l'enseignant.
    class PrepareInterrosQueryTest < ActiveSupport::TestCase
      Actor = Entities::Identity::Actor
      DUE = Date.current + 2

      setup do
        @course = create_course
        @n1 = create_essential(course: @course, name: "Notion 1", position: 1)
        @n2 = create_essential(course: @course, name: "Notion 2", position: 2)
        @n3 = create_essential(course: @course, name: "Notion 3", position: 3)
        # Créés dans le désordre : l'ordre vient des notions, pas de l'insertion.
        @e3 = create_exercise(essential: @n3, title: "Ex 3")
        @e1 = create_exercise(essential: @n1, title: "Ex 1")
        @e2 = create_exercise(essential: @n2, title: "Ex 2")
        @w2 = create_lesson_wide_exercise(course: @course, title: "Large 2", position: 12)
        @w1 = create_lesson_wide_exercise(course: @course, title: "Large 1", position: 11)
      end

      def call(actor) = PrepareInterrosQuery.new.call(course_slug: @course.slug, actor:)
      def student_actor(student) = Actor.new(user_id: student.id, role: :student)
      def states(prepare) = (prepare.groups.flat_map(&:exercises) + prepare.lesson_wide).to_h { [ it.title, it.student_state ] }

      test "le contrat porte groups, lesson_wide et targets" do
        assert_equal %i[groups lesson_wide targets], PrepareInterrosQuery::Prepare.members
      end

      test "les exercices publiés sont groupés par notion dans l'ordre des notions, puis ceux de toute la leçon par position" do
        prepare = call(nil)

        assert_equal [ %w[Notion\ 1 Notion\ 2 Notion\ 3], [ [ "Ex 1" ], [ "Ex 2" ], [ "Ex 3" ] ] ],
                     [ prepare.groups.map(&:title), prepare.groups.map { |group| group.exercises.map(&:title) } ]
        assert_equal [ @n1.slug, @n2.slug, @n3.slug ], prepare.groups.map(&:essential_slug)
        assert_equal [ "Large 1", "Large 2" ], prepare.lesson_wide.map(&:title)
      end

      test "chaque ligne porte son type et son nombre de questions" do
        row = call(nil).groups.first.exercises.first

        assert_equal [ @e1.public_id, @e1.exercise_type, 2 ], [ row.public_id, row.exercise_type, row.questions_count ]
      end

      test "une notion sans exercice publié n'a pas de groupe ; un brouillon est caché hors équipe" do
        create_exercise(essential: create_essential(course: @course, name: "Vide"), status: "draft", title: "Brouillon")

        prepare = call(nil)

        assert_equal 3, prepare.groups.size
        assert_not_includes (prepare.groups.flat_map(&:exercises) + prepare.lesson_wide).map(&:title), "Brouillon"
      end

      test "l'élève ne voit ni brouillon, ni archivé, ni notion non publiée, ni exercice d'une autre leçon" do
        create_exercise(essential: @n1, status: "draft", title: "Brouillon")
        create_exercise(essential: @n1, status: "archived", title: "Archivé", archived_at: Time.current)
        create_lesson_wide_exercise(course: @course, status: "draft", title: "Large brouillon")
        draft_notion = create_essential(course: @course, name: "Notion brouillon", status: "draft")
        create_exercise(essential: draft_notion, title: "Sous notion brouillon")
        create_exercise(title: "Autre leçon")
        create_lesson_wide_exercise(title: "Autre leçon large")

        prepare = call(student_actor(create_student))

        assert_equal [ "Ex 1", "Ex 2", "Ex 3" ], prepare.groups.flat_map(&:exercises).map(&:title)
        assert_equal [ "Large 1", "Large 2" ], prepare.lesson_wide.map(&:title)
        assert_nil prepare.targets
      end

      test "l'équipe lit aussi les brouillons, avec leur statut" do
        create_exercise(essential: @n1, status: "draft", title: "Brouillon", position: 50)
        team = Actor.new(user_id: create_team_member.id, role: :team, team_role: "admin")

        rows = call(team).groups.first.exercises

        assert_equal [ "Ex 1", "Brouillon" ], rows.map(&:title)
        assert_equal %w[published draft], rows.map(&:status)
        assert_nil call(team).targets
      end

      test "une leçon sans exercice rend des listes vides" do
        empty = create_course
        prepare = PrepareInterrosQuery.new.call(course_slug: empty.slug, actor: nil)

        assert_equal [ [], [] ], [ prepare.groups, prepare.lesson_wide ]
      end

      test "un cours inconnu rend des listes vides" do
        prepare = PrepareInterrosQuery.new.call(course_slug: "inconnu", actor: nil)

        assert_equal [ [], [] ], [ prepare.groups, prepare.lesson_wide ]
      end

      test "hors élève, aucun état n'est calculé" do
        assert_nil call(nil).groups.first.exercises.first.student_state
      end

      test "l'élève voit « à revoir » avant l'assignation, qui passe avant la meilleure note" do
        classroom = create_classroom(level: @course.level)
        student = create_student(classroom:)
        teacher = create_teacher(classrooms: [ classroom ])
        create_gap(student:, essential: @n1)
        create_assignment(classroom:, assignable: @e1, by: teacher, due_on: DUE)
        create_assignment(classroom:, assignable: @e2, by: teacher, due_on: DUE)
        create_exercise_session(student:, exercise: @e1, status: "completed", score_percent: 70)
        create_exercise_session(student:, exercise: @e3, status: "completed", score_percent: 70)

        states = states(call(student_actor(student)))

        assert_equal :to_review, states["Ex 1"].kind
        assert_equal [ :due, DUE ], [ states["Ex 2"].kind, states["Ex 2"].due_on ]
        assert_equal [ :score, 70 ], [ states["Ex 3"].kind, states["Ex 3"].score_percent ]
        assert_nil states["Large 1"]
      end

      test "une assignation rendue laisse la meilleure note" do
        classroom = create_classroom(level: @course.level)
        student = create_student(classroom:)
        assignment = create_assignment(classroom:, assignable: @e2, by: create_teacher(classrooms: [ classroom ]), due_on: DUE)
        create_exercise_session(student:, exercise: @e2, status: "completed", score_percent: 40, classroom_assignment: assignment)
        create_exercise_session(student:, exercise: @e2, status: "completed", score_percent: 75, classroom_assignment: assignment)

        state = states(call(student_actor(student)))["Ex 2"]

        assert_equal [ :score, 75 ], [ state.kind, state.score_percent ]
      end

      test "l'assignation d'une autre classe ou archivée ne compte pas" do
        classroom = create_classroom(level: @course.level)
        student = create_student(classroom:)
        teacher = create_teacher(classrooms: [ classroom ])
        create_assignment(classroom: create_classroom(level: @course.level), assignable: @e1, by: teacher, due_on: DUE)
        create_assignment(classroom:, assignable: @e2, by: teacher, due_on: DUE, status: "archived")

        assert_nil states(call(student_actor(student)))["Ex 1"]
        assert_nil states(call(student_actor(student)))["Ex 2"]
      end

      test "la lacune d'un autre élève ou levée ne compte pas" do
        classroom = create_classroom(level: @course.level)
        student = create_student(classroom:)
        create_gap(student: create_student(classroom:), essential: @n1)
        create_gap(student:, essential: @n2, status: "remediated")

        assert_nil states(call(student_actor(student)))["Ex 1"]
        assert_nil states(call(student_actor(student)))["Ex 2"]
      end

      test "l'enseignant reçoit ses classes du niveau, avec l'assignation active de chaque exercice" do
        classroom = create_classroom(name: "3ème 1", level: @course.level)
        other = create_classroom(name: "3ème 2", level: @course.level)
        teacher = create_teacher(classrooms: [ classroom ])
        assignment = create_assignment(classroom:, assignable: @e2, by: teacher)

        targets = call(Actor.new(user_id: teacher.id, role: :teacher, school_id: classroom.school_id)).targets

        assert_equal [ "3ème 1" ], targets.classrooms.map(&:name)
        assert_equal assignment.public_id, targets.states.fetch([ classroom.public_id, @e2.public_id ]).assignment_public_id
        assert_not_includes targets.classrooms.map(&:public_id), other.public_id
      end
    end
  end
end
