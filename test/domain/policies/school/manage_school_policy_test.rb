require "test_helper"

module Policies
  module School
    class ManageSchoolPolicyTest < ActiveSupport::TestCase
      test "autorise l'équipe" do
        assert ManageSchoolPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role: :team, team_role: "field")).success?
      end

      test "refuse élève, enseignant, direction et anonyme" do
        %i[student teacher school_admin].each do |role|
          assert_equal :forbidden, ManageSchoolPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role:)).code
        end
        assert_equal :forbidden, ManageSchoolPolicy.new.call(actor: nil).code
      end
    end
  end
end
