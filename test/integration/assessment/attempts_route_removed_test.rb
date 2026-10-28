require "test_helper"

# CA-23 (1re partie), ADR-0112: the old « one question at a time » screen is gone. Sending one answer of a copy has no
# route any more; the copy is sent whole (exercise_session_copy).
class Assessment::AttemptsRouteRemovedTest < ActionDispatch::IntegrationTest
  test "posting a single answer to a session answers 404, and nothing is recorded" do
    course = create_course
    student = create_student_for(course)
    exercise = create_exercise(course:, lesson_wide: true, questions: 1)
    session = create_exercise_session(student:, exercise:)
    sign_in_as student

    assert_no_difference -> { Orm::QuestionAttempt.count } do
      post "/sessions/#{session.public_id}/attempts", params: { question_id: 1, answer_id: 1 }
    end

    assert_response :not_found
  end

  test "no named route for the attempts remains" do
    assert_not_respond_to Rails.application.routes.url_helpers, :exercise_session_attempts_path
  end

  test "the copy route stays" do
    assert_respond_to Rails.application.routes.url_helpers, :exercise_session_copy_path
  end
end
