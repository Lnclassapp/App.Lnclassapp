require "test_helper"

module Queries
  module Catalog
    # UDR parcours-matiere-exercice §3 : le prochain exercice de l'élève dans une matière ou une leçon ; reprise d'abord, puis
    # le suivant du dernier terminé, puis le premier non terminé ; deux requêtes au plus.
    class NextExerciseQueryTest < ActiveSupport::TestCase
      setup do
        @level = create_level
        @maths = create_material(name: "Mathématiques")
        @lesson2 = create_course(level: @level, material: @maths, name: "Les angles", subtitle: "Leçon 2")
        @lesson10 = create_course(level: @level, material: @maths, name: "Les vecteurs", subtitle: "Leçon 10")
        # Créés dans le désordre : l'ordre vient du numéro de leçon puis de la position, pas de l'insertion.
        @a10 = create_lesson_wide_exercise(course: @lesson10, title: "A10")
        @a2 = create_lesson_wide_exercise(course: @lesson2, title: "A2")
        @b2 = create_lesson_wide_exercise(course: @lesson2, title: "B2")
        @student = create_student
        @audience = Entities::Catalog::LevelAudience.new(pairs: [ [ @level.id, nil ] ])
      end

      def call(**) = NextExerciseQuery.new.call(student_id: @student.id, audience: @audience, material: @maths.slug, **)
      def finish(exercise, at: Time.current) = create_exercise_session(student: @student, exercise:, status: "completed", completed_at: at)

      test "CA-1: sans activité, le premier exercice dans l'ordre du programme (leçon 2 avant leçon 10), à commencer" do
        row = call

        assert_equal [ :start, @a2.public_id, "A2", "Les angles", nil, nil ],
                     [ row.kind, row.exercise_public_id, row.title, row.lesson_name, row.session_public_id, row.resume_number ]
      end

      test "CA-2: une session en cours se reprend à la question suivante ; la plus récente gagne" do
        create_exercise_session(student: @student, exercise: @a10, started_at: 2.days.ago, answered_count: 1)
        recent = create_exercise_session(student: @student, exercise: @b2, started_at: 1.hour.ago, answered_count: 1)

        row = call

        assert_equal [ :resume, @b2.public_id, recent.public_id, 2 ], [ row.kind, row.exercise_public_id, row.session_public_id, row.resume_number ]
      end

      test "CA-3: après le dernier terminé, le premier non terminé qui le suit" do
        finish(@a2, at: 2.days.ago)

        assert_equal @b2.public_id, call.exercise_public_id
      end

      test "CA-2: la session la plus récente gagne même sur l'exercice le plus tard du programme ; le numéro suit les réponses" do
        create_exercise_session(student: @student, exercise: @b2, started_at: 3.days.ago, answered_count: 1)
        recent = create_exercise_session(student: @student, exercise: @a10, started_at: 1.hour.ago, answered_count: 3)

        row = call

        assert_equal [ @a10.public_id, recent.public_id, 4 ], [ row.exercise_public_id, row.session_public_id, row.resume_number ]
      end

      test "CA-3: seul B2 terminé, on propose l'exercice qui le suit (A10), pas le premier non terminé (A2)" do
        finish(@b2, at: 1.day.ago)

        assert_equal @a10.public_id, call.exercise_public_id
      end

      test "CA-3: le dernier terminé est le plus récent, pas le plus avancé dans le programme" do
        c = create_lesson_wide_exercise(course: @lesson10, title: "C10")
        # Ordre du programme : A2 < B2 < A10 < C10.
        finish(c, at: 2.days.ago)
        finish(@a2, at: 1.day.ago)

        assert_equal @b2.public_id, call.exercise_public_id
      end

      test "un autre élève en cours sur un candidat ne change rien pour cet élève" do
        create_exercise_session(student: create_student, exercise: @a2, answered_count: 1)

        row = call

        assert_equal [ :start, @a2.public_id, nil ], [ row.kind, row.exercise_public_id, row.session_public_id ]
      end

      test "une session terminée sans date ne plante pas, garde son exercice terminé et n'est pas le dernier" do
        finish(@a2, at: nil)
        finish(@b2, at: 1.day.ago)

        assert_equal @a10.public_id, call.exercise_public_id
      end

      test "une session abandonnée seule : l'exercice est reproposé à commencer" do
        create_exercise_session(student: @student, exercise: @a2, status: "abandoned")

        row = call

        assert_equal [ :start, @a2.public_id ], [ row.kind, row.exercise_public_id ]
      end

      test "CA-3: rien ne suit le dernier terminé : retour au premier non terminé" do
        finish(@a10, at: 1.day.ago)

        assert_equal [ :start, @a2.public_id ], call.then { [ it.kind, it.exercise_public_id ] }
      end

      test "CA-4: tout terminé, aucune carte" do
        [ @a2, @b2, @a10 ].each { finish(it) }

        assert_nil call
      end

      test "CA-4: aucun candidat, aucune carte, et une seule requête" do
        nothing = create_material(name: "Philosophie")
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }

        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          assert_nil NextExerciseQuery.new.call(student_id: @student.id, audience: @audience, material: nothing.slug)
        end

        assert_equal 1, count
        assert_nil NextExerciseQuery.new.call(student_id: @student.id, audience: Entities::Catalog::LevelAudience.none, material: @maths.slug)
      end

      test "deux requêtes au plus" do
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/) }

        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { call }

        assert_operator count, :<=, 2
      end

      test "CA-5: course_slug limite à la leçon" do
        assert_equal @a10.public_id, call(material: nil, course_slug: @lesson10.slug).exercise_public_id
        assert_nil NextExerciseQuery.new.call(student_id: @student.id, audience: @audience, course_slug: "inconnue")
      end

      test "l'ordre suit la position de la notion avant celle de l'exercice, puis les exercices de toute la leçon" do
        late = create_essential(course: @lesson2, position: 9)
        early = create_essential(course: @lesson2, position: 1)
        create_exercise(essential: late, title: "Tardif", position: 80)
        create_exercise(essential: early, title: "Précoce", position: 99)

        assert_equal "Précoce", call(course_slug: @lesson2.slug, material: nil).title
        finish(Orm::Exercise.find_by!(title: "Précoce"))
        assert_equal "Tardif", call(course_slug: @lesson2.slug, material: nil).title
      end

      test "CA-6: brouillon, archivé, notion non publiée, leçon non publiée et autre niveau ne sont jamais proposés" do
        [ @a2, @b2, @a10 ].each { finish(it) }
        create_lesson_wide_exercise(course: @lesson2, status: "draft", title: "Brouillon")
        create_lesson_wide_exercise(course: @lesson2, status: "archived", title: "Archivé", archived_at: Time.current)
        create_lesson_wide_exercise(course: @lesson2, title: "Publié archivé", archived_at: Time.current)
        create_exercise(essential: create_essential(course: @lesson2, status: "draft"), title: "Sous notion brouillon")
        draft_lesson = create_course(level: @level, material: @maths, status: "draft", subtitle: "Leçon 1")
        create_lesson_wide_exercise(course: draft_lesson, title: "Leçon brouillon")
        other_level = create_course(level: create_level, material: @maths, subtitle: "Leçon 1")
        create_lesson_wide_exercise(course: other_level, title: "Autre niveau")

        assert_nil call
      end

      test "un exercice de notion publiée est proposé" do
        create_exercise(essential: create_essential(course: @lesson2), title: "Notion publiée", position: 50)
        [ @a2, @b2, @a10 ].each { finish(it) }

        assert_equal "Notion publiée", call.title
      end
    end
  end
end
