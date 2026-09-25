require "test_helper"

module Policies
  module Classroom
    class ManageClassroomPolicyTest < ActiveSupport::TestCase
      test "l'équipe seule en V1" do
        assert ManageClassroomPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role: :team)).success?
        %i[student teacher school_admin].each do |role|
          assert_equal :forbidden, ManageClassroomPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role:)).code
        end
        assert_equal :forbidden, ManageClassroomPolicy.new.call(actor: nil).code
      end
    end
  end
end
