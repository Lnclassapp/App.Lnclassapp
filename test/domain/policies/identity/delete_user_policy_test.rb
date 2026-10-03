require "test_helper"

module Policies
  module Identity
    class DeleteUserPolicyTest < ActiveSupport::TestCase
      test "l'équipe seule" do
        assert DeleteUserPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role: :team, team_role: "admin")).success?
        %i[student teacher school_admin].each do |role|
          assert_equal :forbidden, DeleteUserPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role:)).code
        end
        assert_equal :forbidden, DeleteUserPolicy.new.call(actor: nil).code
      end
    end
  end
end
