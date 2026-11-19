require "test_helper"

module Queries
  module Communication
    class PushCandidates
      class LastActivityTest < ActiveSupport::TestCase
        def at(*users) = LastActivity.new.at(user_ids: users.map(&:id))

        test "aucun identifiant, aucune requête" do
          assert_equal({}, LastActivity.new.at(user_ids: []))
        end

        test "un élève sans activité est absent" do
          assert_equal({}, at(create_student))
        end

        test "la plus récente de la lecture, de la session et de la réponse" do
          student = create_student
          session = create_exercise_session(student:)
          session.update_columns(started_at: 5.days.ago, completed_at: 4.days.ago)
          assert_in_delta 4.days.ago, at(student).fetch(student.id), 5

          create_attempt(session:)
          Orm::QuestionAttempt.where(exercise_session_id: session.id).update_all(answered_at: 2.days.ago)
          assert_in_delta 2.days.ago, at(student).fetch(student.id), 5

          essential = create_essential
          Orm::EssentialRead.create!(student:, essential:, first_read_at: 3.days.ago, last_read_at: 1.day.ago)
          assert_in_delta 1.day.ago, at(student).fetch(student.id), 5
        end

        test "un compte anonymisé ou qui n'est pas un élève est ignoré" do
          teacher = create_teacher
          anonymized = create_student
          anonymized.update_columns(anonymized_at: Time.current)
          create_exercise_session(student: anonymized)

          assert_equal({}, at(teacher, anonymized))
        end
      end
    end
  end
end
