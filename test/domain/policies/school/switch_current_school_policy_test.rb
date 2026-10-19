require "test_helper"

module Policies
  module School
    # ME-08 (ADR-0094 §4.3): a teacher switches only to one of their own schools.
    class SwitchCurrentSchoolPolicyTest < ActiveSupport::TestCase
      def actor(role: :teacher) = Entities::Identity::Actor.new(user_id: 7, role:, team_role: ("admin" if role == :team), school_id: 31)
      def call(actor:, attached:) = SwitchCurrentSchoolPolicy.new.call(actor:, attached:)

      test "a teacher switches to a school they are attached to" do
        assert call(actor: actor, attached: true).success?
      end

      test "a teacher may not switch to a school they are not attached to" do
        assert_equal :forbidden, call(actor: actor, attached: false).code
      end

      test "students, directions, the team and visitors have no current school to switch" do
        %i[student school_admin team].each { assert_equal :forbidden, call(actor: actor(role: it), attached: true).code, it }
        assert_equal :forbidden, call(actor: nil, attached: true).code
      end
    end
  end
end
