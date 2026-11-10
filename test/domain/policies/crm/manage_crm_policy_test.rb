require "test_helper"

# ADR-XXXX (contexte crm) §4, CA-01, CA-02: only the team, as admin or field, reaches the follow-up of the schools.
module Policies
  module Crm
    class ManageCrmPolicyTest < ActiveSupport::TestCase
      def actor(role, team_role = nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)

      test "admin and field members of the team are allowed" do
        %w[admin field].each { assert ManageCrmPolicy.new.call(actor: actor(:team, it)).success?, it }
      end

      test "content, teacher, student, school admin and the visitor receive :forbidden" do
        [ actor(:team, "content"), actor(:teacher), actor(:student), actor(:school_admin), nil ].each do |someone|
          assert_equal :forbidden, ManageCrmPolicy.new.call(actor: someone).code, someone.inspect
        end
      end
    end
  end
end
