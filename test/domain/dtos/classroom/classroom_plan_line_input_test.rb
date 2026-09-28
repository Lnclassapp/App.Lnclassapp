require "test_helper"

# BC-03: the two counts of a line of the barème, whole numbers from 0 to 30, kept as typed for the 422.
module Dtos
  module Classroom
    class ClassroomPlanLineInputTest < ActiveSupport::TestCase
      def errors_of(public_count: "4", private_count: "2")
        ClassroomPlanLineInput.new(public_count:, private_count:).tap(&:validate).errors
      end

      test "two whole numbers from 0 to 30 are valid, and become the counts by type" do
        input = ClassroomPlanLineInput.new(public_count: " 30 ", private_count: "0")

        assert input.valid?
        assert_equal({ "public" => 30, "private" => 0 }, input.counts)
        assert_equal({ "public" => 7, "private" => 3 }, ClassroomPlanLineInput.new(public_count: 7, private_count: "3").counts)
      end

      test "both counts are required" do
        errors = errors_of(public_count: "", private_count: nil)

        assert errors.of_kind?(:public_count, :blank)
        assert errors.of_kind?(:private_count, :blank)
      end

      test "a count is a whole number from 0 to 30, never a text turned into zero" do
        assert errors_of(public_count: "quatre").of_kind?(:public_count, :not_a_number)
        assert errors_of(public_count: "2.5").of_kind?(:public_count, :not_an_integer)
        assert errors_of(private_count: "-1").of_kind?(:private_count, :greater_than_or_equal_to)
        assert errors_of(private_count: "31").of_kind?(:private_count, :less_than_or_equal_to)
        assert_equal "quatre", ClassroomPlanLineInput.new(public_count: "quatre").public_count
      end

      test "built from the current counts of a line, an undefined count stays empty" do
        input = ClassroomPlanLineInput.from_counts({ "public" => 4, "private" => nil })

        assert_equal [ "4", nil ], [ input.public_count, input.private_count ]
      end
    end
  end
end
