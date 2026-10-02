require "test_helper"

module Repositories
  module Assessment
    # ADR-0036, amendement (2) : un compte supprimé sur demande perd ses résultats, ligne par ligne, sans cascade ; ceux des
    # autres élèves restent.
    class LearningDataEraserTest < ActiveSupport::TestCase
      setup do
        @essential = create_essential
        @exercise = create_exercise(essential: @essential)
        @student = create_student
        @other = create_student
      end

      # Un parcours complet : échec, lacune ouverte, remédiation réussie qui la résout et gagne un badge.
      def learning_path(student)
        failed = create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent: 0)
        create_attempt(session: failed, correct: false)
        gap = create_gap(student:, essential: @essential, source_session: failed)
        remediation = create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent: 100, gap:)
        create_attempt(session: remediation)
        gap.update!(status: "remediated", resolved_by_session: remediation, resolved_at: Time.current)
        create_badge(student:, exercise: @exercise, session: remediation)
        create_exercise_session(student:, exercise: create_exercise(essential: @essential))
        { sessions: [ failed, remediation ], gap: }
      end

      def scopes(student)
        sessions = Orm::ExerciseSession.where(student:)
        [ sessions, Orm::QuestionAttempt.where(exercise_session: sessions), Orm::ExerciseBadge.where(student:),
          Orm::KnowledgeGap.where(student:) ]
      end

      def counts(student) = scopes(student).map(&:count)
      def rows(student) = scopes(student).map { |scope| scope.order(:id).map(&:attributes) }

      test "sessions, attempts, badges and gaps of the student are erased; those of another student stay untouched" do
        learning_path(@student)
        learning_path(@other)
        others = rows(@other)

        assert_equal [ 3, 2, 1, 1 ], counts(@student)
        assert LearningDataEraser.new.erase_for(student_id: @student.id)

        assert_equal [ 0, 0, 0, 0 ], counts(@student)
        assert_equal others, rows(@other)
        assert Orm::User.exists?(@student.id)
      end

      test "a gap resolved by the session of another student does not block the erasure, and that session stays" do
        own_gap = create_gap(student: @student, essential: @essential)
        rescuer = create_exercise_session(student: @other, exercise: @exercise, status: "completed")
        own_gap.update!(status: "self_corrected", resolved_by_session: rescuer)

        LearningDataEraser.new.erase_for(student_id: @student.id)

        assert_not Orm::KnowledgeGap.exists?(own_gap.id)
        assert Orm::ExerciseSession.exists?(rescuer.id)
      end

      test "the gap of another student resolved by one of the student's sessions only loses that reference, and stays resolved" do
        others_gap = create_gap(student: @other, essential: @essential)
        session = create_exercise_session(student: @student, exercise: @exercise, status: "completed")
        others_gap.update!(status: "self_corrected", resolved_by_session: session, resolved_at: Time.current)

        LearningDataEraser.new.erase_for(student_id: @student.id)

        assert_not Orm::ExerciseSession.exists?(session.id)
        assert_equal [ "self_corrected", nil, @other.id ], others_gap.reload.attributes.values_at("status", "resolved_by_session_id", "student_id")
        assert_not_nil others_gap.resolved_at
      end

      test "a student without results is a no-op" do
        learning_path(@other)

        assert LearningDataEraser.new.erase_for(student_id: @student.id)
        assert_equal [ 3, 2, 1, 1 ], counts(@other)
      end
    end
  end
end
