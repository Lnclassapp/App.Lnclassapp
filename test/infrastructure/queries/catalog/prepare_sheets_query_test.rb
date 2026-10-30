require "test_helper"

module Queries
  module Catalog
    # UDR feuilles-prepare-interros-et-devoirs §3 (structure) : une feuille par notion, une dernière « Toute la leçon », une feuille par
    # sujet de devoir ; chaque exercice avec ses questions, son indice, sa figure et, pour l'élève, sa dernière copie terminée.
    class PrepareSheetsQueryTest < ActiveSupport::TestCase
      Actor = Entities::Identity::Actor

      setup do
        @course = create_course(name: "Thalès")
        @n1 = create_essential(course: @course, name: "Notion 1", position: 1, sheet: { "remember" => "À retenir 1" })
        @n2 = create_essential(course: @course, name: "Notion 2", position: 2)
        @n3 = create_essential(course: @course, name: "Notion 3", position: 3)
        # Créés dans le désordre : l'ordre vient des notions, pas de l'insertion.
        @e3 = create_exercise(essential: @n3, title: "Ex 3")
        @e1 = create_exercise(essential: @n1, title: "Ex 1", hint: "Relis l'énoncé.")
        @e2 = create_exercise(essential: @n2, title: "Ex 2")
        @w2 = create_lesson_wide_exercise(course: @course, title: "Large 2", position: 12)
        @w1 = create_lesson_wide_exercise(course: @course, title: "Large 1", position: 11)
      end

      def call(actor) = PrepareSheetsQuery.new.call(course_slug: @course.slug, actor:)
      def student_actor(student) = Actor.new(user_id: student.id, role: :student)
      def team_actor = Actor.new(user_id: create_team_member.id, role: :team, team_role: "admin")
      def titles(sheet) = sheet.exercises.map(&:title)

      test "le contrat porte les feuilles de Prépare interros et de Prépare devoirs, les cibles, les notions vides et l'en-tête du cours" do
        assert_equal %i[interros devoirs targets bare course_name material_name level_name], PrepareSheetsQuery::Prepare.members
        prepare = call(nil)

        assert_equal [ "Thalès", @course.material.name, @course.level.name ], [ prepare.course_name, prepare.material_name, prepare.level_name ]
      end

      test "une feuille par notion dans l'ordre des notions, puis « Toute la leçon » par position, numérotées de 1 à N" do
        interros = call(nil).interros

        assert_equal [ "Notion 1", "Notion 2", "Notion 3", nil ], interros.map { it.title if it.kind == :notion }
        assert_equal %i[notion notion notion lesson_wide], interros.map(&:kind)
        assert_equal [ [ "Ex 1" ], [ "Ex 2" ], [ "Ex 3" ], [ "Large 1", "Large 2" ] ], interros.map { titles(it) }
        assert_equal [ [ 1, 4 ], [ 2, 4 ], [ 3, 4 ], [ 4, 4 ] ], interros.map { [ it.number, it.total ] }
        assert_equal [ "notion-#{@n1.slug}", "notion-#{@n2.slug}", "notion-#{@n3.slug}", "toute-la-lecon" ], interros.map(&:dom_id)
        assert_equal [ 1, 2 ], interros.last.exercises.map(&:number)
      end

      test "la feuille d'une notion porte son « À retenir », la feuille de toute la leçon n'en porte pas" do
        interros = call(nil).interros

        assert_equal "À retenir 1", interros.first.note
        assert_nil interros.second.note, "un « À retenir » vide n'est pas rendu"
        assert_nil interros.last.note
      end

      test "une leçon sans feuille de toute la leçon n'en invente pas" do
        [ @w1, @w2 ].each { it.update!(status: "archived", archived_at: Time.current) }

        assert_equal 3, call(nil).interros.size
      end

      test "chaque exercice porte son indice, sa figure citée et son énoncé" do
        @course.update!(figures: [ { "key" => "tri", "kind" => "triangle", "params" => {}, "description" => "Un triangle", "controls" => [] } ])
        @e1.update!(figure_key: "tri", statement: "Dans le triangle ABC…")

        exercise = call(nil).interros.first.exercises.first

        assert_equal [ "Relis l'énoncé.", "Dans le triangle ABC…" ], [ exercise.hint, exercise.statement ]
        assert_equal "Un triangle", exercise.figure.description
        assert_nil call(nil).interros.second.exercises.first.hint
      end

      test "les sujets de devoir forment une section à part, un sujet sans exercice visible n'y figure pas" do
        subject = create_subject(course: @course, title: "Sujet A", notions: "Thalès, réciproque")
        create_subject(course: @course, title: "Sujet vide", notions: "Rien")
        create_exercise(subject:, course: @course, title: "S1 ex 2", position: 31)
        create_exercise(subject:, course: @course, title: "S1 ex 1", position: 30)
        create_exercise(subject:, course: @course, title: "S1 brouillon", position: 32, status: "draft")

        devoirs = call(student_actor(create_student)).devoirs

        assert_equal 1, devoirs.size
        sheet = devoirs.first
        assert_equal [ :subject, "Sujet A", "Thalès, réciproque", 1, 1, "sujet-#{subject.position}" ],
                     [ sheet.kind, sheet.title, sheet.note, sheet.number, sheet.total, sheet.dom_id ]
        assert_equal [ "S1 ex 1", "S1 ex 2" ], titles(sheet)
        assert_equal 2, call(student_actor(create_student)).devoirs.first.exercises.size
        assert_equal 3, call(team_actor).devoirs.first.exercises.size, "l'équipe lit le brouillon du sujet"
      end

      test "sans sujet, la section Prépare devoirs est vide" do
        assert_equal [], call(nil).devoirs
      end

      test "les questions sont dans l'ordre, chacune avec son type de feuille, ses propositions dans l'ordre des positions, sans correction" do
        exercise = create_exercise(essential: @n1, title: "Ex types", questions: 0, position: 40)
        create_kind_question(exercise:, question_type: "fill_blank", content: "AM/AB = AN/___", answers: [ "AC", "CA" ])
        create_kind_question(exercise:, question_type: "numeric", content: "Calcule MN.", answers: [ "6" ], explanation: "6 cm").update!(unit: "cm")
        true_false = exercise.questions.create!(position: 3, content: "Vrai ?", question_type: "true_false")
        true_false.answers.create!(position: 1, content: "Vrai", correct: true)
        true_false.answers.create!(position: 2, content: "Faux", correct: false)

        questions = call(student_actor(create_student)).interros.first.exercises.find { it.public_id == exercise.public_id }.questions

        assert_equal %i[fill_in calculation true_false], questions.map(&:kind)
        assert_equal [ 1, 2, 3 ], questions.map(&:number)
        assert_equal [ "Vrai", "Faux" ], questions.last.choices.map(&:content)
        assert_equal [ 0, 1 ], questions.last.choices.map(&:index)
        assert_equal "cm", questions.second.unit
        assert_equal [ nil, nil, nil ], questions.map(&:good_answer), "aucune correction avant la vérification"
        assert_equal [ nil, nil, nil ], questions.map(&:explanation)
      end

      test "une question à choix unique est un QCM, lettrée A, B, C… dans l'ordre des positions" do
        question = call(nil).interros.first.exercises.first.questions.first

        assert_equal :mcq, question.kind
        assert_equal %w[A B C D], question.choices.map(&:letter)
        assert_equal [ "Proposition 1", "Proposition 2", "Proposition 3", "Proposition 4" ], question.choices.map(&:content)
      end

      test "les autres types gardent leur partiel d'aujourd'hui : la question est rendue par la session de lecture" do
        exercise = create_exercise(essential: @n1, title: "Ex autres", questions: 0, position: 41)
        create_kind_question(exercise:, question_type: "select", content: "Choisis ___", answers: [ "a", "b" ])
        create_kind_question(exercise:, question_type: "ordering", content: "Range", answers: [ "un", "deux", "trois" ])

        questions = call(nil).interros.first.exercises.find { it.public_id == exercise.public_id }.questions

        assert_equal %i[other other], questions.map(&:kind)
        assert_equal %w[select ordering], questions.map { it.play.kind_name }
        assert_equal [ 0, 1 ], questions.first.play.answers.map(&:index)
        assert_equal 3, questions.last.play.items.size
        assert_nil questions.last.verdict
      end

      test "l'élève sans copie voit chaque exercice à faire, la progression à zéro" do
        student = create_student

        sheet = call(student_actor(student)).interros.first

        assert_nil sheet.exercises.first.copy
        assert_equal 0, sheet.passed
      end

      test "la dernière copie terminée de l'élève corrige l'exercice : verdicts, bonne réponse, explication, note" do
        exercise = create_exercise(essential: @n1, title: "Ex copie", questions: 0, position: 42)
        fill = create_kind_question(exercise:, question_type: "fill_blank", content: "A/___", answers: [ "AC" ], explanation: "Même droite.")
        choice = exercise.questions.create!(position: 2, content: "Laquelle ?", question_type: "single_choice", explanation: "La B.")
        a, b, = [ [ 1, "Faux", false ], [ 2, "Juste", true ], [ 3, "Autre", false ] ].map do |position, content, correct|
          choice.answers.create!(position:, content:, correct:)
        end
        student = create_student
        session = create_exercise_session(student:, exercise:, status: "completed", score_percent: 50)
        session.update!(correct_count: 1, question_count: 2)
        Orm::QuestionAttempt.create!(exercise_session: session, question: fill, correct: true, selected_answer_ids: [], response_text: "AC", answered_at: Time.current)
        Orm::QuestionAttempt.create!(exercise_session: session, question: choice, correct: false, selected_answer_ids: [ a.id ], answered_at: Time.current)

        sheet = call(student_actor(student)).interros.first
        copy = sheet.exercises.find { it.public_id == exercise.public_id }
        text, mcq = copy.questions

        assert_equal [ session.public_id, false ], [ copy.copy.session_public_id, copy.copy.passed ]
        assert_equal [ 5.0, :fair ], [ copy.copy.grade.score, copy.copy.grade.mention ]
        assert_equal [ :correct, "AC", "AC", "Même droite." ], [ text.verdict, text.response, text.good_answer, text.explanation ]
        assert_equal [ :wrong, "B. Juste", "La B." ], [ mcq.verdict, mcq.good_answer, mcq.explanation ]
        assert_equal [ true, false, false ], mcq.choices.map(&:picked)
        assert_equal 0, sheet.passed
        assert_not_nil b
      end

      test "une copie sans réponse à une question donne « sans réponse » ; toutes justes, l'exercice est réussi et compté" do
        exercise = create_exercise(essential: @n2, title: "Ex vide", questions: 0, position: 43)
        fill = create_kind_question(exercise:, question_type: "fill_blank", content: "A/___", answers: [ "AC" ])
        student = create_student
        session = create_exercise_session(student:, exercise:, status: "completed", score_percent: 0)
        Orm::QuestionAttempt.create!(exercise_session: session, question: fill, correct: false, selected_answer_ids: [], unanswered: true, answered_at: Time.current)
        other = create_exercise_session(student:, exercise: @e2, status: "completed", score_percent: 100)

        sheet = call(student_actor(student)).interros.second
        empty = sheet.exercises.find { it.public_id == exercise.public_id }

        assert_equal :empty, empty.questions.first.verdict
        assert_equal [ 1, true ], [ sheet.passed, sheet.exercises.find { it.public_id == @e2.public_id }.copy.passed ]
        assert_equal other.public_id, sheet.exercises.find { it.public_id == @e2.public_id }.copy.session_public_id
      end

      test "la dernière copie terminée l'emporte sur une plus ancienne, une copie commencée ne compte pas" do
        student = create_student
        create_exercise_session(student:, exercise: @e1, status: "completed", score_percent: 0, completed_at: 2.days.ago).update!(correct_count: 0)
        latest = create_exercise_session(student:, exercise: @e1, status: "completed", score_percent: 100, completed_at: 1.hour.ago)
        Orm::ExerciseSession.where(id: latest.id).update_all(started_at: 1.day.ago)
        create_exercise_session(student:, exercise: @e2, status: "started")

        sheets = call(student_actor(student)).interros

        assert_equal latest.public_id, sheets.first.exercises.first.copy.session_public_id
        assert_nil sheets.second.exercises.first.copy
      end

      test "la copie d'un autre élève n'est jamais lue ; hors élève, aucune copie" do
        create_exercise_session(student: create_student, exercise: @e1, status: "completed", score_percent: 100)

        assert_nil call(student_actor(create_student)).interros.first.exercises.first.copy
        assert_nil call(nil).interros.first.exercises.first.copy
        assert_nil call(team_actor).interros.first.exercises.first.copy
      end

      test "une notion sans exercice publié n'a pas de feuille ; un brouillon est caché hors équipe" do
        create_exercise(essential: create_essential(course: @course, name: "Vide"), status: "draft", title: "Brouillon")

        prepare = call(nil)

        assert_equal 3, prepare.interros.count { it.kind == :notion }
        assert_not_includes prepare.interros.flat_map { titles(it) }, "Brouillon"
        assert_equal [ "Vide" ], prepare.bare.map(&:title), "elle garde son repère, sans exercice"
      end

      test "l'élève ne voit ni brouillon, ni archivé, ni notion non publiée, ni exercice d'une autre leçon" do
        create_exercise(essential: @n1, status: "draft", title: "Brouillon")
        create_exercise(essential: @n1, status: "archived", title: "Archivé", archived_at: Time.current)
        # Seul archived_at écarte celui-ci : son statut dit encore « publié ».
        create_exercise(essential: @n1, title: "Publié archivé", archived_at: Time.current)
        create_lesson_wide_exercise(course: @course, status: "draft", title: "Large brouillon")
        draft_notion = create_essential(course: @course, name: "Notion brouillon", status: "draft")
        create_exercise(essential: draft_notion, title: "Sous notion brouillon")
        create_exercise(title: "Autre leçon")
        create_lesson_wide_exercise(title: "Autre leçon large")

        prepare = call(student_actor(create_student))

        assert_equal [ "Ex 1", "Ex 2", "Ex 3", "Large 1", "Large 2" ], prepare.interros.flat_map { titles(it) }
        assert_nil prepare.targets
      end

      test "l'équipe lit aussi les brouillons, jamais un exercice archivé" do
        create_exercise(essential: @n1, status: "draft", title: "Brouillon", position: 50)
        create_exercise(essential: @n1, status: "archived", title: "Archivé", archived_at: Time.current)
        create_lesson_wide_exercise(course: @course, status: "draft", title: "Large brouillon")

        prepare = call(team_actor)

        assert_equal [ "Ex 1", "Brouillon" ], titles(prepare.interros.first)
        assert_equal [ "Large 1", "Large 2", "Large brouillon" ], titles(prepare.interros.last).sort
        assert_nil prepare.targets
      end

      test "une leçon sans exercice, ou un cours inconnu, rend des listes vides" do
        empty = PrepareSheetsQuery.new.call(course_slug: create_course.slug, actor: nil)
        unknown = PrepareSheetsQuery.new.call(course_slug: "inconnu", actor: nil)

        assert_equal [ [], [] ], [ empty.interros, empty.devoirs ]
        assert_equal [ [], [] ], [ unknown.interros, unknown.devoirs ]
      end

      test "on retrouve l'exercice et sa feuille par son public_id" do
        prepare = call(nil)

        assert_equal "Ex 2", prepare.exercise(@e2.public_id).title
        assert_equal "Notion 2", prepare.sheet_of(@e2.public_id).title
        assert_nil prepare.exercise("inconnu")
        assert_nil prepare.sheet_of("inconnu")
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

      # CA-17 (prepare-interros-cahier, Lot C) : « due » : l'élève doit encore rendre cet exercice, la feuille ne le vérifie pas.
      test "un exercice assigné à l'élève et pas rendu porte due ; rendu, ou pour un autre rôle, non" do
        classroom = create_classroom(level: @course.level, series: @course.series)
        student = create_student(classroom:)
        assignment = create_assignment(classroom:, assignable: @e2)
        due = ->(actor) { call(actor).interros.flat_map(&:exercises).select(&:due).map(&:title) }

        assert_equal [ "Ex 2" ], due.call(student_actor(student))
        assert_empty due.call(nil)
        assert_empty due.call(team_actor)

        create_exercise_session(student:, exercise: @e2, status: "completed", classroom_assignment_id: assignment.id)

        assert_empty due.call(student_actor(student))
      end
    end
  end
end
