require "test_helper"

module Ports
  module Classroom
    class AssignmentRepositoryPortTest < ActiveSupport::TestCase
      Resolved = AssignmentRepositoryPort::ResolvedAssignable

      test "une ressource est lisible si elle et ses parents sont publiés" do
        assignable = Entities::Classroom::Assignable.new(type: "Essential", id: 1, key: "mitose")
        course_level = { level_id: 6, series_id: nil }

        assert Resolved.new(assignable:, status: "published", parents_published: true, course_level:).readable?
        assert_not Resolved.new(assignable:, status: "published", parents_published: false, course_level:).readable?
        assert_not Resolved.new(assignable:, status: "draft", parents_published: true, course_level:).readable?
      end
    end
  end
end
