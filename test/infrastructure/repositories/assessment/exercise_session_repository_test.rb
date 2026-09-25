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
