require "test_helper"

module Entities
  module Classroom
    class AssignableTest < ActiveSupport::TestCase
      test "seul un exercice s'assigne (ADR-0072 §4.1)" do
        assignable = Assignable.new(type: "Exercise", id: 3, key: "Xy12", name: "Mitose")

        assert_equal "Xy12", assignable.key
        assert_nil Assignable.new(type: "Exercise", id: 1, key: "Ab34").name
        assert_equal %w[Exercise], Assignable::TYPES
      end

      test "un cours ou une fiche lève ArgumentError" do
        assert_raises(ArgumentError) { Assignable.new(type: "Course", id: 1, key: "svt") }
        assert_raises(ArgumentError) { Assignable.new(type: "Essential", id: 1, key: "mitose") }
      end

      test "un type hors liste lève ArgumentError" do
        assert_raises(ArgumentError) { Assignable.new(type: "ExamSubject", id: 1, key: "x") }
      end
    end
  end
end
