require "test_helper"

module Entities
  module Classroom
    class AssignmentTest < ActiveSupport::TestCase
      def build(status)
        Assignment.new(id: 1, public_id: "p", classroom_id: 2, assignable: Assignable.new(type: "Course", id: 1, key: "svt"),
                       status:, assigned_by_id: 3, assigned_at: Time.current, archived_at: nil)
      end

      test "active ou archivée" do
        assert build("active").active?
        assert_not build("archived").active?
        assert_equal %w[active archived], Assignment::STATUSES
      end
    end
  end
end
