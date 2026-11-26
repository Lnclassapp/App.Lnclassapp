require "test_helper"

# UDR XXXX (écran notifications de l'équipe) §3.1, §3.3 : every team role may view the push settings.
module Policies
  module Communication
    class ViewPushSettingsPolicyTest < ActiveSupport::TestCase
      def actor(role, team_role: nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)

      test "every team role may view" do
        %w[admin content field].each do |team_role|
          assert_predicate ViewPushSettingsPolicy.new.call(actor: actor(:team, team_role:)), :success?
        end
      end

      test "a teacher, a school admin, a student or a visitor is forbidden" do
        [ actor(:teacher), actor(:school_admin), actor(:student), nil ].each do |someone|
          assert_equal :forbidden, ViewPushSettingsPolicy.new.call(actor: someone).code
        end
      end
    end
  end
end
