require "test_helper"

# hors-connexion, Lot 0 (ADR §4.5, menace R2) : la copie hors ligne s'écrit une fois ; le rejeu rend :duplicate sans rien écrire.
module Repositories
  module Assessment
    class ExerciseSessionRepositoryOfflineTest < ActiveSupport::TestCase
      UUID = "3f2b8a1e-5c4d-4e6f-9a7b-1c2d3e4f5a6b".freeze

      setup do
        @repository = ExerciseSessionRepository.new
        @student = create_student
        @exercise = create_exercise(questions: 2)
        @received = Time.utc(2026, 11, 12, 12)
      end

      def session(public_id: "offline0000001")
        Entities::Assessment::ExerciseSession.new(
          id: nil, public_id:, student_id: @student.id, exercise_id: @exercise.id, status: "completed", question_count: 2, answered_count: 2,
          correct_count: 1, progress_percent: 100, score_percent: 50, kind: "standard", knowledge_gap_id: nil, classroom_assignment_id: nil,
          started_at: @received - 600, completed_at: @received - 60
        )
      end

      def attempts
        @exercise.questions.map.with_index do |question, index|
          { question_id: question.id, selected_answer_ids: [], response_text: "x", correct: index.zero?, unanswered: false }
        end
      end

      def record(public_id: "offline0000001") = @repository.record_offline_copy(session: session(public_id:), attempts:, client_copy_id: UUID, received_at: @received)

      test "la copie est écrite terminée avec ses tentatives, son identifiant et l'heure de réception" do
        saved = record

        assert_predicate saved, :completed?
        assert_equal 2, @repository.attempts(session_id: saved.id).size
        row = Orm::ExerciseSession.find(saved.id)
        assert_equal [ UUID, @received ], [ row.client_copy_id, row.received_at ]
        assert_equal saved, @repository.find_by_client_copy_id(student_id: @student.id, client_copy_id: UUID)
      end

      test "un second envoi rend :duplicate et n'écrit rien de plus" do
        record

        assert_no_difference [ "Orm::ExerciseSession.count", "Orm::QuestionAttempt.count" ] do
          assert_equal :duplicate, record(public_id: "offline0000002")
        end
      end

      test "une violation d'unicité qui n'est pas un rejeu remonte" do
        create_exercise_session(student: @student, exercise: @exercise, status: "completed", public_id: "offline0000001")

        assert_raises(ActiveRecord::RecordNotUnique) { record }
      end

      test "find_by_client_copy_id : rien pour un autre élève" do
        record

        assert_nil @repository.find_by_client_copy_id(student_id: create_student.id, client_copy_id: UUID)
      end
    end
  end
end
