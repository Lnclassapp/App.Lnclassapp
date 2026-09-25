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
        assert_equal attempt.selected_answer_ids, feedback.selected_answer_ids
        assert_equal play.next_question.answers.size, feedback.answers.size
        assert feedback.answers.none? { it.respond_to?(:correct) }
      end

      test "pas de verdict pour une question non tentée, d'un autre exercice, ou sans demande" do
        assert_nil play(feedback_question_id: @questions.first.id).last_feedback
        assert_nil play(feedback_question_id: create_exercise.questions.first.id).last_feedback
        assert_nil play(feedback_question_id: nil).last_feedback
      end

      test "session inconnue : nil" do
        assert_nil SessionPlayQuery.new.call(public_id: "inconnue")
      end

      test "type de question : nombre de propositions à cocher" do
        question = SessionPlayQuery::Question.new(id: 1, number: 1, content: "Q", question_type: "multiple_correct_3", answers: [])

        assert_equal [ 3, true ], [ question.expected_count, question.multiple? ]
        assert_not question.with(question_type: "true_false").multiple?
      end
    end
  end
end
