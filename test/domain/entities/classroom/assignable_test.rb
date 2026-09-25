require "test_helper"

module Entities
  module Classroom
    class AssignableTest < ActiveSupport::TestCase
      test "cours, fiche ou exercice" do
        assignable = Assignable.new(type: "Exercise", id: 3, key: "Xy12", name: "Mitose")

        assert_equal "Xy12", assignable.key
        assert_nil Assignable.new(type: "Course", id: 1, key: "svt").name
      end

      test "un type hors liste lève ArgumentError" do
        assert_raises(ArgumentError) { Assignable.new(type: "ExamSubject", id: 1, key: "x") }
      end
    end
  end
end
