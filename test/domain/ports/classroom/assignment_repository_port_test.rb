require "test_helper"

module Ports
  module Classroom
    class AssignmentRepositoryPortTest < ActiveSupport::TestCase
      Resolved = AssignmentRepositoryPort::ResolvedAssignable

      test "une ressource est lisible si elle et ses parents sont publiés" do
        assignable = Entities::Classroom::Assignable.new(type: "Essential", id: 1, key: "mitose")

        assert Resolved.new(assignable:, status: "published", parents_published: true).readable?
        assert_not Resolved.new(assignable:, status: "published", parents_published: false).readable?
        assert_not Resolved.new(assignable:, status: "draft", parents_published: true).readable?
      end
    end
  end
end
