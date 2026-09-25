require "test_helper"

# AS-02 (plan boucle-pedagogique, Lot C1) : la progression d'un élève sur un exercice. Meilleur score et maîtrise des seules
# sessions terminées, badge (ADR-0033), session en cours à reprendre. Ni un autre élève ni un autre exercice ne comptent.
module Queries
  module Assessment
    class ExerciseProgressQueryTest < ActiveSupport::TestCase
      setup do
        @student = create_student
        @exercise = create_exercise
      end

      def progress = ExerciseProgressQuery.new.call(student_id: @student.id, exercise_id: @exercise.id)

      test "un élève qui n'a jamais ouvert l'exercice" do
        assert_equal({ badge_level: nil, best_score_percent: nil, mastery: nil, completed_count: 0, started_session_public_id: nil },
                     progress.to_h)
      end

      test "meilleur score, maîtrise et nombre des sessions terminées ; badge ; session en cours" do
        create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 40)
        best = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 85)
        create_exercise_session(student: @student, exercise: @exercise, status: "abandoned")
        started = create_exercise_session(student: @student, exercise: @exercise, status: "started")
        create_badge(student: @student, exercise: @exercise, level: "gold", session: best)
        other = create_student
        create_exercise_session(student: other, exercise: @exercise, status: "completed", score_percent: 100)
        create_exercise_session(student: other, exercise: @exercise, status: "started")
        create_exercise_session(student: @student, exercise: create_exercise, status: "completed", score_percent: 100)
        create_badge(student: @student, level: "diamond")

        assert_equal({ badge_level: :gold, best_score_percent: 85, mastery: :acquired, completed_count: 2,
                       started_session_public_id: started.public_id }, progress.to_h)
      end

      test "la maîtrise suit les seuils de l'ADR-0033" do
        create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 50)

        assert_equal [ 50, :fragile, 1, nil ], progress.to_h.values_at(:best_score_percent, :mastery, :completed_count, :badge_level)
      end
    end
  end
end
