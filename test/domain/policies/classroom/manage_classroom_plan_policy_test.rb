require "test_helper"

# BC-08, ADR-0058: the team reads and changes the barème, like the rest of the referential.
module Policies
  module Classroom
    class ManageClassroomPlanPolicyTest < ActiveSupport::TestCase
      test "allows every team member" do
        %w[admin content field].each do |team_role|
          assert ManageClassroomPlanPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role: :team, team_role:)).success?
        end
      end

      test "refuses student, teacher, school admin and anonymous" do
        %i[student teacher school_admin].each do |role|
          assert_equal :forbidden, ManageClassroomPlanPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role:)).code
        end
        assert_equal :forbidden, ManageClassroomPlanPolicy.new.call(actor: nil).code
      end
    end
  end
end
