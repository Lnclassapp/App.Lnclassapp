require "test_helper"

# ADR-0092 §4.3 (ED-21, ED-22) : seule l'équipe admin ou field change une fonction ; aucune direction, ni la sienne ni une autre.
module Policies
  module School
    class SetStaffPositionPolicyTest < ActiveSupport::TestCase
      def actor(role, team_role: nil, staff_position: nil)
        Entities::Identity::Actor.new(user_id: 1, role:, team_role:, school_id: (7 unless role == :team), staff_position:)
      end

      setup { @policy = SetStaffPositionPolicy.new }

      test "ED-23: the admin and field team members change a position" do
        %w[admin field].each { assert @policy.call(actor: actor(:team, team_role: it)).success?, it }
      end

      test "ED-21, ED-22: every direction is refused, the head of school included" do
        %w[head deputy educator secretary].each do |staff_position|
          assert_equal :forbidden, @policy.call(actor: actor(:school_admin, staff_position:)).code, staff_position
        end
      end

      test "the content team member, a teacher, a student and the visitor are refused" do
        assert_equal :forbidden, @policy.call(actor: actor(:team, team_role: "content")).code
        assert_equal :forbidden, @policy.call(actor: actor(:teacher)).code
        assert_equal :forbidden, @policy.call(actor: actor(:student)).code
        assert_equal :forbidden, @policy.call(actor: nil).code
      end
    end
  end
end
