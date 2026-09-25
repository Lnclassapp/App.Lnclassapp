require "test_helper"

module Repositories
  module Assessment
    class BadgeRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = BadgeRepository.new
        @student = create_student
        @exercise = create_exercise
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      def badge(level, session)
        Entities::Assessment::Badge.new(student_id: @student.id, exercise_id: @exercise.id, session_id: session.id, level:,
                                        awarded_at: @at)
      end

      test "pose puis remplace le badge d'un élève sur un exercice, une seule ligne" do
        first = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 60)
        second = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 100)

        assert_equal badge(:bronze, first), @repository.upsert(badge: badge(:bronze, first))
        @repository.upsert(badge: badge(:diamond, second))

        found = @repository.find(student_id: @student.id, exercise_id: @exercise.id)

        assert_instance_of Entities::Assessment::Badge, found
        assert_equal [ :diamond, second.id, @at ], [ found.level, found.session_id, found.awarded_at ]
        assert_equal 1, Orm::ExerciseBadge.where(student: @student).count
      end

      test "aucun badge : nil" do
        assert_nil @repository.find(student_id: @student.id, exercise_id: @exercise.id)
      end
    end
  end
end
