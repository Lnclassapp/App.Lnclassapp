require "test_helper"

module Queries
  module Assessment
    # AS-11, AS-12, AS-39 (ADR-0033, ADR-0054) : le résultat d'une session terminée — score, note sur 20, maîtrise, palier
    # de badge, « Nouveau badge ! » — et sa correction question par question. Sans reveal, seules les propositions
    # cochées sont lues, et jamais la colonne answers.correct ; avec reveal, toutes, propositions correctes marquées.
    class SessionResultQueryTest < ActiveSupport::TestCase
      setup do
        @student = create_student(first_name: "Awa", last_name: "Koné")
        @essential = create_essential(name: "Division cellulaire")
        @exercise = create_exercise(essential: @essential, title: "Méiose", questions: 2)
        @first, @second = @exercise.questions.order(:position).to_a
        @first.update!(content: "Combien de cellules ?", explanation: "Quatre cellules filles.")
        @first.answers.order(:position).each_with_index { |answer, index| answer.update!(content: "Q1 proposition #{index + 1}") }
        @second.answers.order(:position).each_with_index { |answer, index| answer.update!(content: "Q2 proposition #{index + 1}") }
        @session = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 50)
        create_attempt(session: @session, question: @first, correct: false)
        create_attempt(session: @session, question: @second, correct: true)
      end

      def result(reveal: false, session: @session) = SessionResultQuery.new.call(public_id: session.public_id, reveal:)

      test "session inconnue : nil" do
        assert_nil SessionResultQuery.new.call(public_id: "inconnue", reveal: true)
      end

      test "en-tête : exercice, fiche essentielle, élève, score, note, maîtrise et palier tirés de Grading" do
        row = result

        assert_equal [ @exercise.public_id, "Méiose" ], [ row.exercise.public_id, row.exercise.title ]
        assert_equal [ @essential.slug, "Division cellulaire", @essential.course.slug ],
                     [ row.essential.slug, row.essential.name, row.essential.course_slug ]
        assert_equal [ @session.public_id, @student.id, "Awa Koné" ], [ row.session_public_id, row.student_id, row.student_name ]
        assert_equal [ 50, 10, 1, 2, :fragile, :bronze ],
                     [ row.score_percent, row.grade_on_20, row.correct_count, row.question_count, row.mastery, row.badge_level ]
      end

      test "palier du score de la session : 9 bonnes réponses sur 10 donnent Or, jamais Diamant ; sous le seuil, aucun" do
        gold = Entities::Assessment::Grading::GOLD_THRESHOLD + 10
        failed = Entities::Assessment::Grading::PASS_THRESHOLD - 10
        @session.update!(score_percent: gold)
        assert_equal [ :gold, :acquired, 18 ], [ result.badge_level, result.mastery, result.grade_on_20 ]

        @session.update!(score_percent: failed)
        assert_equal [ nil, :struggling ], [ result.badge_level, result.mastery ]
      end

      test "« Nouveau badge ! » seulement si le badge de l'élève a été gagné par cette session" do
        assert_not result.earned_now

        badge = create_badge(student: @student, exercise: @exercise, level: "bronze", session: @session)
        assert result.earned_now

        badge.update!(exercise_session: create_exercise_session(student: @student, exercise: @exercise, status: "completed"))
        assert_not result.earned_now
      end

      test "sans reveal : verdict, explication et seules les propositions cochées, sans la colonne correct" do
        statements = []
        callback = ->(*, payload) { statements << payload[:sql] }
        review = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { result.review }

        first, second = review
        assert_equal [ @first.id, 1, "Combien de cellules ?", "Quatre cellules filles.", false ],
                     [ first.id, first.number, first.content, first.explanation, first.correct ]
        assert_equal [ [ "Q1 proposition 2", true, nil ] ], first.answers.map { [ it.content, it.selected, it.correct ] }
        assert_equal [ 2, true, nil ], [ second.number, second.correct, second.explanation ]
        assert_equal [ [ "Q2 proposition 1", true, nil ] ], second.answers.map { [ it.content, it.selected, it.correct ] }

        answers_sql = statements.grep(/FROM "answers"/)
        assert_not_empty answers_sql
        assert answers_sql.none? { it.include?('"answers"."correct"') }, answers_sql.join("\n")
      end

      test "avec reveal : toutes les propositions, dans l'ordre, cochées et correctes marquées" do
        first, second = result(reveal: true).review

        assert_equal [ [ "Q1 proposition 1", false, true ], [ "Q1 proposition 2", true, false ],
                       [ "Q1 proposition 3", false, false ], [ "Q1 proposition 4", false, false ] ],
                     first.answers.map { [ it.content, it.selected, it.correct ] }
        assert_equal [ true, false, false, false ], second.answers.map(&:correct)
        assert_equal [ true, false, false, false ], second.answers.map(&:selected)
      end

      test "une question sans tentative reste dans la correction, sans verdict ni proposition cochée" do
        Orm::QuestionAttempt.where(question: @second).delete_all

        second = result.review.second
        assert_nil second.correct
        assert_empty second.answers
      end

      test "enseignant : seulement celui d'une classe active où l'élève est encore inscrit" do
        classroom = create_classroom
        Orm::ClassroomStudent.create!(classroom:, student: @student, primary: true, joined_at: Time.current)
        teacher = create_teacher(classrooms: [ classroom ])
        query = SessionResultQuery.new

        assert query.teaches_student?(student_id: @student.id, teacher_id: teacher.id)
        assert_not query.teaches_student?(student_id: @student.id, teacher_id: create_teacher(classrooms: [ create_classroom ]).id)

        classroom.update!(status: "archived", archived_at: Time.current)
        assert_not query.teaches_student?(student_id: @student.id, teacher_id: teacher.id)

        classroom.update!(status: "active", archived_at: nil)
        Orm::ClassroomStudent.where(student: @student).update_all(left_at: Time.current)
        assert_not query.teaches_student?(student_id: @student.id, teacher_id: teacher.id)
      end
    end
  end
end
