require "test_helper"

module Queries
  module Assessment
    # AS-08, AS-09, AS-10 (ADR-0054) : la prochaine question est la première sans tentative ; ses propositions sont
    # mélangées dans un ordre stable par session et ne portent jamais la correction ; le verdict ne vient que d'une tentative.
    class SessionPlayQueryTest < ActiveSupport::TestCase
      setup do
        @exercise = create_exercise(title: "Méiose", questions: 3)
        @questions = @exercise.questions.order(:position).to_a
        @questions.first.update!(explanation: "La méiose donne quatre cellules.")
        @session = create_exercise_session(exercise: @exercise)
      end

      def play(session = @session, **options) = SessionPlayQuery.new.call(public_id: session.public_id, **options)

      test "session neuve : la question de position la plus basse, progression à 0" do
        row = play

        assert_equal [ @session.public_id, @session.student_id, "started", @exercise.public_id, "Méiose", 0, 3, 0 ],
                     [ row.session_public_id, row.student_id, row.status, row.exercise_public_id, row.exercise_title,
                       row.answered_count, row.question_count, row.progress_percent ]
        assert_not row.completed?
        assert_equal [ @questions.first.id, 1, "<p>Question 1</p>", "single_choice" ],
                     [ row.next_question.id, row.next_question.number, row.next_question.content, row.next_question.question_type ]
        assert_equal @questions.first.answers.map(&:id).sort, row.next_question.answers.map(&:id).sort
        assert_nil row.last_feedback
      end

      test "reprise : la première question sans tentative, même si une question plus loin est déjà tentée" do
        create_attempt(session: @session, question: @questions.third)
        create_attempt(session: @session, question: @questions.first)

        assert_equal [ @questions.second.id, 2 ], [ play.next_question.id, play.next_question.number ]
      end

      test "toutes les questions tentées : plus de prochaine question" do
        @questions.each { create_attempt(session: @session, question: it) }
        @session.update!(status: "completed", score_percent: 100, completed_at: Time.current, answered_count: 3)

        row = play
        assert_nil row.next_question
        assert row.completed?
      end

      test "ordre des propositions mélangé, identique à chaque lecture de la même session" do
        orders = Array.new(3) { play.next_question.answers.map(&:id) }

        assert_equal 1, orders.uniq.size
        other_orders = Array.new(8) { play(create_exercise_session(exercise: @exercise)).next_question.answers.map(&:id) }
        assert other_orders.uniq.size > 1, "l'ordre ne dépend pas de la session"
      end

      test "aucune colonne correct n'est lue sur les propositions : la prochaine question ne peut rien dévoiler" do
        statements = []
        callback = ->(*, payload) { statements << payload[:sql] }
        row = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { play }

        answers_sql = statements.grep(/FROM "answers"/)
        assert_not_empty answers_sql
        assert answers_sql.none? { it.include?("correct") }, answers_sql.join("\n")
        assert row.next_question.answers.none? { it.respond_to?(:correct) }
      end

      test "verdict de la question tentée : juste ou non, les propositions cochées et l'explication, sans les propositions correctes" do
        attempt = create_attempt(session: @session, question: @questions.first, correct: false)

        feedback = play(feedback_question_id: @questions.first.id).last_feedback
        assert_equal [ @questions.first.id, 1, "<p>Question 1</p>", "La méiose donne quatre cellules.", false ],
                     [ feedback.question_id, feedback.number, feedback.content, feedback.explanation, feedback.correct ]
        assert_equal attempt.selected_answer_ids, feedback.selected_answers.map(&:id)
        assert feedback.selected_answers.none? { it.respond_to?(:correct) }
      end

      test "le verdict ne contient que les propositions cochées : une proposition juste non choisie n'est jamais lue" do
        create_attempt(session: @session, question: @questions.first, correct: false)
        right = @questions.first.answers.find_by!(correct: true)

        statements = []
        callback = ->(*, payload) { statements << payload[:sql] }
        row = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { play(feedback_question_id: @questions.first.id) }

        assert_equal [ "Proposition 2" ], row.last_feedback.selected_answers.map(&:content)
        assert_not_includes row.last_feedback.selected_answers.map(&:id), right.id
        answers_sql = statements.grep(/FROM "answers"/)
        assert answers_sql.none? { it.include?("correct") }, answers_sql.join("\n")
      end

      test "pas de verdict pour une question non tentée, d'un autre exercice, ou sans demande" do
        assert_nil play(feedback_question_id: @questions.first.id).last_feedback
        assert_nil play(feedback_question_id: create_exercise.questions.first.id).last_feedback
        assert_nil play(feedback_question_id: nil).last_feedback
      end

      # ADR-0105, UDR-0129 §3.4 : la question porte son image (adresse, texte de remplacement, dimensions) ; sans image, nil.
      test "la prochaine question porte son image ; une question sans image n'en porte pas" do
        image = create_question_image(question: @questions.second, alt: "Une pile", fixture: "photos/photo.png")
        create_attempt(session: @session, question: @questions.first)

        assert_equal SessionPlayQuery::Image.new(public_id: image.public_id, alt: "Une pile", width: 64, height: 48),
                     play.next_question.image
        create_attempt(session: @session, question: @questions.second)
        assert_nil play.next_question.image
      end

      # CA-9, ADR-0091 §4.4 : rien de la solution dans les données de la page.
      def kind_session(question_type, answers, **options)
        exercise = create_exercise(questions: 0)
        question = create_kind_question(exercise:, question_type:, answers:, **options)
        [ create_exercise_session(exercise:), question ]
      end

      def sql_of
        statements = []
        callback = ->(*, payload) { statements << payload[:sql] }
        result = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
        [ result, statements.grep(/FROM "answers"/) ]
      end

      test "trous et nombre : aucune ligne answers n'est lue avant la réponse" do
        { "fill_blank" => [ "Abidjan", "Abijan" ], "numeric" => [ "-3,5" ] }.each do |question_type, answers|
          session, question = kind_session(question_type, answers, content: "Réponds ___ .")

          row, answers_sql = sql_of { play(session) }
          assert_empty answers_sql, question_type
          assert_equal [ question.id, question_type, [], [], [] ],
                       [ row.next_question.id, row.next_question.kind_name, row.next_question.answers, row.next_question.items,
                         row.next_question.prompts ]
        end
      end

      test "ordre : les étapes mélangées par la session, avec leur indice d'affichage et sans aucun identifiant" do
        session, question = kind_session("ordering", %w[Écrire Développer Réduire Calculer])
        steps = question.answers.order(:position).to_a

        items = play(session).next_question.items
        expected = Entities::Assessment::AnswerShuffle.for(session_id: session.id, question_id: question.id, ids: steps.map(&:id), avoid: steps.map(&:id))
        assert_equal expected.map { |id| steps.find { it.id == id }.content }, items.map(&:content)
        assert_equal [ 0, 1, 2, 3 ], items.map(&:index)
        assert items.none? { it.respond_to?(:id) }
        assert_empty play(session).next_question.answers
      end

      test "relier : la gauche dans l'ordre des positions, la droite mélangée, sans aucun identifiant" do
        pairs = [ %w[3(x+1) 3x+3], %w[2(x-4) 2x-8], %w[5(2+x) 10+5x] ]
        session, question = kind_session("matching", pairs)

        next_question = play(session).next_question
        assert_equal %w[3(x+1) 2(x-4) 5(2+x)], next_question.prompts
        ids = question.answers.order(:position).map(&:id)
        shuffled = Entities::Assessment::AnswerShuffle.for(session_id: session.id, question_id: question.id, ids:, avoid: ids)
        assert_equal shuffled.map { pairs[ids.index(it)].last }, next_question.items.map(&:content)
        assert next_question.items.none? { it.respond_to?(:id) }
      end

      test "verdict d'un ordre et d'un relier : la réponse de l'élève, dans son ordre, jamais la bonne" do
        session, ordering = kind_session("ordering", %w[A B C])
        a, b, c = ordering.answers.order(:position).map(&:id)
        Orm::QuestionAttempt.create!(exercise_session: session, question: ordering, correct: false, selected_answer_ids: [ c, a, b ],
                                     answered_at: Time.current)
        feedback = play(session, feedback_question_id: ordering.id).last_feedback
        assert_equal [ "ordering", %w[C A B], [ nil ] ], [ feedback.kind_name, feedback.selected_answers.map(&:content),
                                                           feedback.selected_answers.map(&:id).uniq ]

        matching = create_kind_question(exercise: session.exercise, question_type: "matching", answers: [ %w[a 1], %w[b 2], %w[c 3] ])
        one, two, three = matching.answers.order(:position).map(&:id)
        Orm::QuestionAttempt.create!(exercise_session: session, question: matching, correct: false, selected_answer_ids: [ two, one, three ],
                                     answered_at: Time.current)
        pairs = play(session, feedback_question_id: matching.id).last_feedback.pairs
        assert_equal [ %w[a 2], %w[b 1], %w[c 3] ], pairs.map(&:deconstruct)
      end

      test "verdict d'un texte : le texte saisi, aucune ligne answers lue" do
        session, question = kind_session("numeric", [ "42" ])
        Orm::QuestionAttempt.create!(exercise_session: session, question:, correct: false, selected_answer_ids: [], response_text: "41",
                                     answered_at: Time.current)

        row, answers_sql = sql_of { play(session, feedback_question_id: question.id) }
        assert_equal [ "41", [], [] ], [ row.last_feedback.response_text, row.last_feedback.selected_answers, row.last_feedback.pairs ]
        assert_empty answers_sql
      end

      test "le verdict d'un choix donne la lettre affichée de chaque proposition cochée" do
        shown = play.next_question.answers
        attempt = create_attempt(session: @session, question: @questions.first, correct: true)

        feedback = play(feedback_question_id: @questions.first.id).last_feedback
        assert_equal [ shown.find { it.id == attempt.selected_answer_ids.first }.index ], feedback.selected_answers.map(&:index)
        assert_equal 1, play.resume_number - play.answered_count
      end

      test "session inconnue : nil" do
        assert_nil SessionPlayQuery.new.call(public_id: "inconnue")
      end

      test "type de question : nombre de propositions à cocher" do
        question = SessionPlayQuery::Question.new(id: 1, number: 1, content: "Q", question_type: "multiple_correct_3", answers: [], image: nil)

        assert_equal [ 3, true ], [ question.expected_count, question.multiple? ]
        assert_not question.with(question_type: "true_false").multiple?
      end

      # UDR-0138 §3.2 : la copie montre toutes les questions d'un coup, mélangées de la session, sans une marque de correction.
      test "copy : le sujet et toutes les questions numérotées, propositions mélangées par session, sans colonne correct" do
        @exercise.update!(statement: "Soit ABC un triangle.")
        order = create_kind_question(exercise: @exercise, question_type: "ordering", answers: %w[un deux trois quatre])
        pairs = create_kind_question(exercise: @exercise, question_type: "matching", answers: [ %w[a 1], %w[b 2], %w[c 3] ])
        create_kind_question(exercise: @exercise, question_type: "fill_blank", answers: [ "x" ], content: "Un ___ ici")
        create_question_image(question: @questions.first)
        @session.update!(question_count: 6)

        statements = []
        collector = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }
        copy = ActiveSupport::Notifications.subscribed(collector, "sql.active_record") { SessionPlayQuery.new.copy(public_id: @session.public_id) }

        assert_equal [ @session.public_id, "started", "Soit ABC un triangle.", 6 ],
                     [ copy.session_public_id, copy.status, copy.statement, copy.question_count ]
        assert_equal (1..6).to_a, copy.questions.map(&:number)
        assert_equal @questions.first.answers.map(&:id).sort, copy.questions.first.answers.map(&:id).sort
        assert_equal (0...4).to_a, copy.questions.first.answers.map(&:index)
        assert_not_nil copy.questions.first.image
        ordering = copy.questions.find { it.id == order.id }
        matching = copy.questions.find { it.id == pairs.id }
        assert_equal %w[deux quatre trois un], ordering.items.map(&:content).sort
        assert_not_equal %w[un deux trois quatre], ordering.items.map(&:content)
        assert_equal %w[a b c], matching.prompts
        assert_empty copy.questions.last.answers
        assert statements.none? { it.match?(/correct|explanation|numeric_tolerance/) }, "une colonne de correction a été lue"
        assert_equal 4, statements.size
      end

      # ADR-0115 : la copie porte les points, l'unité, le début de phrase, la liste de choix et le sujet en blocs, jamais le corrigé ni la grille.
      test "copy : points, unité, début de phrase, sujet en blocs et liste de choix, sans corrigé ni grille" do
        @exercise.update!(statement_blocks: [ { "type" => "table", "headers" => %w[a b], "rows" => [ %w[1 2] ] } ])
        numeric = create_kind_question(exercise: @exercise, question_type: "numeric", answers: [ "4" ], explanation: "4 cm")
        numeric.update!(points: "2.5", unit: "cm")
        written = create_kind_question(exercise: @exercise, question_type: "written", answers: [], explanation: "Corrigé type")
        written.update!(points: "3.5", starter: "Car…", criteria: [ "Je cite" ])
        notebook = create_kind_question(exercise: @exercise, question_type: "notebook", answers: [], explanation: "Corrigé cahier")
        select = create_kind_question(exercise: @exercise, question_type: "select", answers: %w[A B C], explanation: "Parce que.")
        select.answers.where.not(content: "A").update_all(correct: false)
        @session.update!(question_count: 7)

        statements = []
        collector = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }
        copy = ActiveSupport::Notifications.subscribed(collector, "sql.active_record") { SessionPlayQuery.new.copy(public_id: @session.public_id) }

        assert_equal [ { "type" => "table", "headers" => %w[a b], "rows" => [ %w[1 2] ] } ], copy.statement_blocks
        by_id = copy.questions.index_by(&:id)
        assert_equal [ BigDecimal("1"), nil, nil ], by_id[@questions.first.id].to_h.values_at(:points, :unit, :starter)
        assert_equal [ BigDecimal("2.5"), "cm" ], by_id[numeric.id].to_h.values_at(:points, :unit)
        assert_equal [ BigDecimal("3.5"), "Car…" ], by_id[written.id].to_h.values_at(:points, :starter)
        assert_equal [ BigDecimal("1") ], [ by_id[notebook.id].points ]
        assert_equal %w[A B C], by_id[select.id].answers.map(&:content).sort
        assert_equal select.answers.map(&:id).sort, by_id[select.id].answers.map(&:id).sort
        assert_equal "select", by_id[select.id].kind_name
        assert statements.none? { it.match?(/correct|explanation|criteria/) }, "une colonne de correction a été lue"
        assert_equal 4, statements.size
      end

      test "copy : la copie sérialisée d'un select et d'un écrit ne porte ni corrigé, ni grille, ni marque de bonne réponse" do
        exercise = create_exercise(questions: 0)
        select = create_kind_question(exercise:, question_type: "select", answers: %w[A B C], explanation: "Parce que.")
        written = create_kind_question(exercise:, question_type: "written", answers: [], explanation: "Corrigé type")
        written.update!(criteria: [ "Je cite", "Je compare" ])
        session = create_exercise_session(exercise:, question_count: 2)

        statements = []
        collector = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }
        copy = ActiveSupport::Notifications.subscribed(collector, "sql.active_record") { SessionPlayQuery.new.copy(public_id: session.public_id) }

        assert_equal [ select.id, written.id ], copy.questions.map(&:id)
        hashes = copy.questions.map(&:to_h)
        assert hashes.none? { it.key?(:criteria) || it.key?(:explanation) || it.key?(:correct) }, hashes.inspect
        selected = copy.questions.find { it.id == select.id }
        assert_equal 3, selected.answers.size
        assert selected.answers.none? { it.to_h.key?(:correct) || it.respond_to?(:correct) }
        assert statements.none? { it.match?(/correct|explanation|criteria/) }, statements.join("\n")
      end

      test "copy : sans sujet en blocs, la clé est nil" do
        assert_nil SessionPlayQuery.new.copy(public_id: @session.public_id).statement_blocks
      end

      test "copy : le mélange suit la session, stable à chaque lecture ; une session inconnue donne nil" do
        other = create_exercise_session(exercise: @exercise)
        reads = Array.new(2) { SessionPlayQuery.new.copy(public_id: @session.public_id).questions.first.answers.map(&:id) }

        assert_equal 1, reads.uniq.size
        assert_nil SessionPlayQuery.new.copy(public_id: "inconnue")
        assert_not_nil SessionPlayQuery.new.copy(public_id: other.public_id)
        assert SessionPlayQuery.new.copy(public_id: @session.public_id).started?
        assert_not SessionPlayQuery.new.copy(public_id: @session.public_id).completed?
      end
    end
  end
end
