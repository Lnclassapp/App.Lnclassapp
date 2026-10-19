require "test_helper"

module Policies
  module School
    # ME-13 to ME-15 (ADR-0094 §4.3): a teacher leaves one of his schools, never his last one.
    class LeaveSchoolPolicyTest < ActiveSupport::TestCase
      def actor(role = :teacher) = Entities::Identity::Actor.new(user_id: 7, role:, team_role: ("admin" if role == :team), school_id: 31)
      def call(actor: self.actor, attached: true, schools_count: 2) = LeaveSchoolPolicy.new.call(actor:, attached:, schools_count:)

      test "a teacher of two or three schools leaves one of them" do
        assert call.success?
        assert call(schools_count: 3).success?
      end

      test "ME-15: never the last school, and the refusal says so" do
        result = call(schools_count: 1)

        assert_equal [ :forbidden, { base: [ :last_school ] } ], [ result.code, result.errors ]
      end

      test "a school he does not belong to does not exist for him" do
        assert_equal :not_found, call(attached: false).code
      end

      test "students, directions, the team and visitors leave nothing" do
        %i[student school_admin team].each { assert_equal :forbidden, call(actor: actor(it)).code, it }
        assert_equal :forbidden, call(actor: nil).code
      end
    end
  end
end
