require "test_helper"

module Repositories
  module Assessment
    class ExerciseSessionRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = ExerciseSessionRepository.new
        @student = create_student
        @exercise = create_exercise(questions: 3)
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      def session(**attributes)
        Entities::Assessment::ExerciseSession.new(
          id: nil, public_id: nil, student_id: @student.id, exercise_id: @exercise.id, status: "started", question_count: 3,
          answered_count: 0, correct_count: 0, progress_percent: 0, score_percent: nil, kind: "standard",
          knowledge_gap_id: nil, classroom_assignment_id: nil, started_at: @at, completed_at: nil, **attributes
        )
      end

      test "ouvre une session, la retrouve par public_id, avec ou sans verrou, et comme session ouverte" do
        started = @repository.start(session: session)

        assert_instance_of Entities::Assessment::ExerciseSession, started
        assert_equal [ "started", 3, @at, 14 ], [ started.status, started.question_count, started.started_at, started.public_id.length ]
        assert_equal started, @repository.find_by_public_id(public_id: started.public_id)
        assert_equal started, Orm::ExerciseSession.transaction { @repository.find_by_public_id(public_id: started.public_id, lock: true) }
        assert_equal started, @repository.started_for(student_id: @student.id, exercise_id: @exercise.id)
        assert_nil @repository.find_by_public_id(public_id: "inconnu")
      end

      test "une seconde ouverture renvoie la session déjà ouverte" do
        first = @repository.start(session: session)

        assert_equal first.id, @repository.start(session: session).id
        assert_equal 1, Orm::ExerciseSession.where(student: @student).count
      end

      test "record_copy écrit toute la copie d'un coup, avec la contrainte unanswered, et tient les compteurs" do
        started = @repository.start(session: session)
        first, second, third = @exercise.questions.to_a
        attempts = [ { question_id: first.id, selected_answer_ids: [ 1 ], response_text: nil, correct: true, unanswered: false },
                     { question_id: second.id, selected_answer_ids: [], response_text: "-3,5", correct: false, unanswered: false },
                     { question_id: third.id, selected_answer_ids: [], response_text: nil, correct: false, unanswered: true } ]

        assert_equal :ok, @repository.record_copy(session_id: started.id, attempts:, at: @at)

        reloaded = @repository.find_by_public_id(public_id: started.public_id)
        assert_equal [ 3, 1, 100 ], [ reloaded.answered_count, reloaded.correct_count, reloaded.progress_percent ]
        assert_equal [ [ [ 1 ], nil, true ], [ [], "-3,5", false ], [ [], nil, false ] ],
                     @repository.attempts(session_id: started.id).map { [ it.selected_answer_ids, it.response_text, it.correct ] }
        assert_equal [ false, false, true ], Orm::QuestionAttempt.where(exercise_session_id: started.id).order(:id).pluck(:unanswered)
      end

      test "record_copy : une question sans réponse ni marque unanswered est refusée par la base" do
        started = @repository.start(session: session)
        attempt = { question_id: @exercise.questions.first.id, selected_answer_ids: [], response_text: nil, correct: false, unanswered: false }

        assert_raises(ActiveRecord::StatementInvalid) { @repository.record_copy(session_id: started.id, attempts: [ attempt ], at: @at) }
      end

      test "record_copy : une seconde copie rend :duplicate et n'écrit rien de plus, compteurs compris" do
        started = @repository.start(session: session)
        questions = @exercise.questions.to_a
        copy = questions.map { { question_id: it.id, selected_answer_ids: [], response_text: nil, correct: false, unanswered: true } }
        @repository.record_copy(session_id: started.id, attempts: copy, at: @at)

        assert_equal :duplicate, @repository.record_copy(session_id: started.id, attempts: copy, at: @at + 1)
        assert_equal 3, Orm::QuestionAttempt.where(exercise_session_id: started.id).count
        assert_equal 3, @repository.find_by_public_id(public_id: started.public_id).answered_count
      end

      test "enregistre chaque tentative une fois et tient les compteurs" do
        started = @repository.start(session: session)
        questions = @exercise.questions.to_a

        assert_equal :recorded, @repository.record_attempt(session_id: started.id, question_id: questions[0].id,
                                                           selected_answer_ids: [ 1 ], correct: true, at: @at)
        assert_equal :recorded, @repository.record_attempt(session_id: started.id, question_id: questions[1].id,
                                                           selected_answer_ids: [ 2 ], correct: false, at: @at + 1)
        assert_equal :duplicate, @repository.record_attempt(session_id: started.id, question_id: questions[1].id,
                                                            selected_answer_ids: [ 1 ], correct: true, at: @at + 2)

        reloaded = @repository.find_by_public_id(public_id: started.public_id)

        assert_equal [ 2, 1, 66 ], [ reloaded.answered_count, reloaded.correct_count, reloaded.progress_percent ]
        assert_equal [ [ questions[0].id, [ 1 ], true ], [ questions[1].id, [ 2 ], false ] ],
                     @repository.attempts(session_id: started.id).map { [ it.question_id, it.selected_answer_ids, it.correct ] }
      end

      # ADR-0091 §4.1 : une réponse saisie (trous, nombre) s'enregistre sans proposition.
      test "enregistre une réponse saisie, sans proposition, et la relit" do
        started = @repository.start(session: session)
        question = @exercise.questions.first

        assert_equal :recorded, @repository.record_attempt(session_id: started.id, question_id: question.id, selected_answer_ids: [],
                                                           response_text: "-3,5", correct: true, at: @at)
        assert_equal [ [ [], "-3,5" ] ], @repository.attempts(session_id: started.id).map { [ it.selected_answer_ids, it.response_text ] }
        assert_raises(ActiveRecord::StatementInvalid) do
          Orm::QuestionAttempt.create!(exercise_session_id: started.id, question_id: @exercise.questions.second.id, selected_answer_ids: [],
                                       correct: true, answered_at: @at)
        end
      end

      test "clôture une session ouverte avec son score, une seule fois" do
        started = @repository.start(session: session)

        assert @repository.complete(id: started.id, score_percent: 80, at: @at)
        @repository.complete(id: started.id, score_percent: 10, at: @at + 1)

        completed = @repository.find_by_public_id(public_id: started.public_id)

        assert_equal [ "completed", 80, @at ], [ completed.status, completed.score_percent, completed.completed_at ]
        assert_nil @repository.started_for(student_id: @student.id, exercise_id: @exercise.id)
      end

      test "abandonne une session ouverte" do
        started = @repository.start(session: session)

        assert @repository.abandon(id: started.id, at: @at)
        assert_equal "abandoned", @repository.find_by_public_id(public_id: started.public_id).status
      end
    end
  end
end
