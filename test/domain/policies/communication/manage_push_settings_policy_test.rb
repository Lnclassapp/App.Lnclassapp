require "test_helper"

# UDR XXXX (écran notifications de l'équipe) §3.1, §3.3 : only the team admin may manage the push settings.
module Policies
  module Communication
    class ManagePushSettingsPolicyTest < ActiveSupport::TestCase
      def actor(role, team_role: nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)

      test "only the team admin may manage" do
        %w[admin].each do |team_role|
          assert_predicate ManagePushSettingsPolicy.new.call(actor: actor(:team, team_role:)), :success?
        end
      end

      test "the other team roles are forbidden" do
        %w[admin content field].excluding(*%w[admin]).each do |team_role|
          assert_equal :forbidden, ManagePushSettingsPolicy.new.call(actor: actor(:team, team_role:)).code
        end
      end

      test "a teacher, a school admin, a student or a visitor is forbidden" do
        [ actor(:teacher), actor(:school_admin), actor(:student), nil ].each do |someone|
          assert_equal :forbidden, ManagePushSettingsPolicy.new.call(actor: someone).code
        end
      end
    end
  end
end
