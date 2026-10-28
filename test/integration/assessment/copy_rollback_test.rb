require "test_helper"

# Menace : une clôture qui échoue après l'écriture des tentatives ne laisse ni tentative ni compteur (la transaction recule).
class Assessment::CopyRollbackTest < ActiveSupport::TestCase
  class FailingClose
    def call(actor:, session:, essential_id:) = Shared::Result.failure(:forbidden)
  end

  test "un faux close qui échoue laisse 0 tentative, la session ouverte et ses compteurs intacts" do
    exercise = create_exercise(questions: 2)
    student = create_student_for(exercise.essential.course)
    session = create_exercise_session(student:, exercise:)
    actor = Entities::Identity::Actor.new(user_id: student.id, role: :student)
    use_case = UseCases::Assessment::SubmitExerciseCopy.new(
      sessions: Repositories::Assessment::ExerciseSessionRepository.new, exercises: Repositories::Assessment::ExerciseRepository.new,
      policy: Policies::Assessment::SubmitAttemptPolicy.new, close: FailingClose.new, transaction: Repositories::Shared::Transaction.new,
      clock: Time.zone
    )

    result = use_case.call(actor:, dto: Dtos::Assessment::CopyInput.new(session_public_id: session.public_id, answers: {}))

    assert_equal :forbidden, result.code
    assert_equal 0, Orm::QuestionAttempt.count
    assert_equal [ "started", 0 ], session.reload.then { [ it.status, it.answered_count ] }
  end
end
