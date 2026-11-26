require "test_helper"

# ADR XXXX (envois de notifications) §4.4 : toute l'équipe valide le plan du jour, quel que soit son rôle d'équipe.
module Policies
  module Communication
    class ApprovePushPolicyTest < ActiveSupport::TestCase
      def actor(role, team_role: nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)

      test "every team role may approve" do
        %w[admin content field].each do |team_role|
          assert_predicate ApprovePushPolicy.new.call(actor: actor(:team, team_role:)), :success?
        end
      end

      test "a teacher, a school admin, a student or a visitor is forbidden" do
        [ actor(:teacher), actor(:school_admin), actor(:student), nil ].each do |someone|
          assert_equal :forbidden, ApprovePushPolicy.new.call(actor: someone).code
        end
      end
    end
  end
end
