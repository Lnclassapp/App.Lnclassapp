require "test_helper"

module Dtos
  module Classroom
    class AssignmentInputTest < ActiveSupport::TestCase
      test "accepte un exercice, clé débarrassée de ses espaces" do
        input = AssignmentInput.new(classroom_public_id: "cls123", assignable_type: "Exercise", assignable_key: " Xy12ab ")

        assert input.valid?
        assert_equal "Xy12ab", input.assignable_key
      end

      # ADR-0072 §4.1 : un cours ou une fiche ne s'assigne plus.
      test "refuse un type hors Assignable::TYPES : cours, fiche, et l'ancien ExamSubject (ADR-0048)" do
        [ nil, "", "Course", "Essential", "ExamSubject", "course", "Orm::Course" ].each do |assignable_type|
          input = AssignmentInput.new(classroom_public_id: "cls123", assignable_type:, assignable_key: "genetique")

          assert_not input.valid?, assignable_type.inspect
          assert input.errors.of_kind?(:assignable_type, :inclusion), assignable_type.inspect
        end
      end

      # UDR enseignant §3.13 (option A) : « Plus tard » n'existe plus, une assignation a toujours une échéance.
      test "« Plus tard » n'existe plus : later n'est plus un attribut (les jours cochés sont prouvés dans session_days_input_test)" do
        assert_raises(ActiveModel::UnknownAttributeError) do
          AssignmentInput.new(classroom_public_id: "cls123", assignable_type: "Exercise", assignable_key: "Xy12ab", later: true)
        end
      end

      test "exige la classe et la clé de la ressource" do
        input = AssignmentInput.new(assignable_type: "Exercise", assignable_key: "   ")

        assert_not input.valid?
        assert input.errors.of_kind?(:classroom_public_id, :blank)
        assert input.errors.of_kind?(:assignable_key, :blank)
      end

      test "sans case des jours (modale non montrée ou valeur absente), l'assignation reste valide et weekdays est nil" do
        input = AssignmentInput.new(classroom_public_id: "cls123", assignable_type: "Exercise", assignable_key: "Xy12ab")
        input.weekdays = nil

        assert input.valid?
        assert_nil input.weekdays
      end

      test "la modale des jours exige au moins un jour, et garde les jours cochés" do
        base = { classroom_public_id: "cls123", assignable_type: "Exercise", assignable_key: "Xy12ab" }

        checked = AssignmentInput.new(**base).tap { it.weekdays = %w[1 3] }
        assert checked.valid?
        assert_equal [ 1, 3 ], checked.weekdays

        none = AssignmentInput.new(**base).tap { it.weekdays = [] }
        assert_not none.valid?
        assert none.errors.of_kind?(:weekdays, :blank)

        forged = AssignmentInput.new(**base).tap { it.weekdays = "pas-une-liste" }
        assert_not forged.valid?
        assert forged.errors.of_kind?(:weekdays, :inclusion)
      end
    end
  end
end
