require "test_helper"

module Policies
  module Identity
    # ADR-0028, ADR-0036 §4: the team alone deletes (anonymizes) an account on request; in this version, a student account.
    class DeleteUserPolicyTest < ActiveSupport::TestCase
      TEAM = Entities::Identity::Actor.new(user_id: 1, role: :team, team_role: "admin")

      def user(role, **) = Entities::Identity::User.new(id: 2, role:, **)

      test "l'équipe seule" do
        assert DeleteUserPolicy.new.call(actor: TEAM).success?
        %i[student teacher school_admin].each do |role|
          assert_equal :forbidden, DeleteUserPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 1, role:)).code
        end
        assert_equal :forbidden, DeleteUserPolicy.new.call(actor: nil).code
      end

      test "un compte élève seulement : enseignant, direction et équipe sont refusés" do
        assert DeleteUserPolicy.new.call(actor: TEAM, target: user("student")).success?
        [ user("teacher"), user("school_admin"), user("team", team_role: "content") ].each do |target|
          assert_equal :forbidden, DeleteUserPolicy.new.call(actor: TEAM, target:).code
        end
        assert_equal :forbidden, DeleteUserPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 2, role: :student),
                                                           target: user("student")).code
      end
    end
  end
end
