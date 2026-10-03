require "test_helper"

module Dtos
  module Classroom
    class AssignmentInputTest < ActiveSupport::TestCase
      test "accepte chacun des trois types assignables, clé débarrassée de ses espaces" do
        Entities::Classroom::Assignable::TYPES.each do |assignable_type|
          input = AssignmentInput.new(classroom_public_id: "cls123", assignable_type:, assignable_key: " genetique ")

          assert input.valid?, assignable_type
          assert_equal "genetique", input.assignable_key
        end
      end

      test "refuse un type hors Assignable::TYPES, dont l'ancien ExamSubject (ADR-0048)" do
        [ nil, "", "ExamSubject", "course", "Orm::Course" ].each do |assignable_type|
          input = AssignmentInput.new(classroom_public_id: "cls123", assignable_type:, assignable_key: "genetique")

          assert_not input.valid?, assignable_type.inspect
          assert input.errors.of_kind?(:assignable_type, :inclusion), assignable_type.inspect
        end
      end

      test "exige la classe et la clé de la ressource" do
        input = AssignmentInput.new(assignable_type: "Course", assignable_key: "   ")

        assert_not input.valid?
        assert input.errors.of_kind?(:classroom_public_id, :blank)
        assert input.errors.of_kind?(:assignable_key, :blank)
      end
    end
  end
end
