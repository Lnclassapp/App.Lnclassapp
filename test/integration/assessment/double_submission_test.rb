require "test_helper"

# AS-09, sécurité n° 30 (ADR-0054) : sur PostgreSQL, deux soumissions concurrentes de la même question — double clic ou
# deux onglets — ne laissent qu'une tentative, answered_count vaut 1 et la seconde est refusée en :conflict.
class Assessment::DoubleSubmissionTest < ActiveSupport::TestCase
  # Deux connexions doivent voir leurs commits respectifs : pas de transaction de test englobante.
  self.use_transactional_tests = false

  PAUSE = 0.5

  # Garde le verrou un instant et le signale : sans lui, la seconde soumission lirait la même session non encore tentée.
  class SlowLockSessions < Repositories::Assessment::ExerciseSessionRepository
    def initialize(locked:)
      super()
      @locked = locked
    end

    def find_by_public_id(public_id:, lock: false)
      super.tap do
        @locked << true
        sleep PAUSE
      end
    end
  end

  setup do
    @student = create_student
    @exercise = create_exercise(questions: 2)
    @question = @exercise.questions.order(:position).first
    @session = create_exercise_session(student: @student, exercise: @exercise)
  end

  teardown do
    connection = ActiveRecord::Base.connection
    connection.truncate_tables(*(connection.tables - %w[schema_migrations ar_internal_metadata]))
  end

  def submit(sessions: Repositories::Assessment::ExerciseSessionRepository.new)
    transaction = Repositories::Shared::Transaction.new
    close = UseCases::Assessment::CloseExerciseSession.new(
      sessions:, badges: Repositories::Assessment::BadgeRepository.new, gaps: Repositories::Assessment::KnowledgeGapRepository.new,
      policy: Policies::Assessment::SubmitAttemptPolicy.new, transaction:, clock: Time.zone
    )
    dto = Dtos::Assessment::AttemptInput.new(session_public_id: @session.public_id, question_id: @question.id,
                                             answer_ids: [ @question.answers.find_by!(correct: true).id ])
    UseCases::Assessment::SubmitQuestionAttempt.new(
      sessions:, exercises: Repositories::Assessment::ExerciseRepository.new, policy: Policies::Assessment::SubmitAttemptPolicy.new,
      close:, transaction:, clock: Time.zone
    ).call(actor: Entities::Identity::Actor.new(user_id: @student.id, role: :student), dto:)
  end

  test "deux soumissions concurrentes de la même question : une tentative, answered_count = 1" do
    locked = Queue.new
    first = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { submit(sessions: SlowLockSessions.new(locked:)) }
    end
    locked.pop
    second = Thread.new { ActiveRecord::Base.connection_pool.with_connection { submit } }
    results = [ first.value, second.value ]

    assert results.first.success?
    assert_equal [ :conflict, { base: [ :already_answered ] } ], [ results.last.code, results.last.errors ]
    assert_equal 1, Orm::QuestionAttempt.where(exercise_session_id: @session.id).count
    assert_equal [ 1, 1, 50, "started" ], @session.reload.values_at(:answered_count, :correct_count, :progress_percent, :status)
  end
end
