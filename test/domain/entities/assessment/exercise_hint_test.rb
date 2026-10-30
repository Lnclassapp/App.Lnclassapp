require "test_helper"

module Entities
  module Assessment
    # ADR-XXXX sujets-de-devoir §4 : l'indice facultatif d'un exercice (1 à 400 caractères) et son sujet de devoir.
    class ExerciseHintTest < ActiveSupport::TestCase
      def exercise(**attributes)
        Exercise.new(title: "Thalès", course_id: 1, exercise_type: "fixation", status: "draft", **attributes)
      end

      test "sans indice, l'exercice est valide et l'indice est nul" do
        assert_predicate exercise, :valid?
        assert_nil exercise.hint
        assert_nil exercise.subject_id
      end

      test "l'indice est nettoyé, un indice vide devient nul" do
        assert_equal "Écris les côtés.", exercise(hint: "  Écris les côtés.\n").hint
        assert_nil exercise(hint: "   ").hint
      end

      test "l'indice fait au plus 400 caractères" do
        assert_predicate exercise(hint: "a" * 400), :valid?
        assert_not exercise(hint: "a" * 401).valid?
      end

      test "un exercice de sujet garde l'id de son sujet" do
        assert_equal 7, exercise(subject_id: 7).subject_id
      end
    end
  end
end
