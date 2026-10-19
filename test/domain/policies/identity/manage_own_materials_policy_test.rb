require "test_helper"

module Policies
  module Identity
    # EPM-08 to EPM-10 (ADR-0103 §4.4): only a teacher, in his current school, replaces his subjects.
    class ManageOwnMaterialsPolicyTest < ActiveSupport::TestCase
      Actor = Entities::Identity::Actor

      setup { @policy = ManageOwnMaterialsPolicy.new }

      test "a teacher with a current school is allowed" do
        assert @policy.call(actor: Actor.new(user_id: 1, role: :teacher, school_id: 31)).success?
      end

      test "a teacher without any school (waiting screen) is refused" do
        assert_equal :forbidden, @policy.call(actor: Actor.new(user_id: 1, role: :teacher)).code
      end

      test "a student, a direction, the team and a visitor are refused" do
        [ Actor.new(user_id: 2, role: :student), Actor.new(user_id: 3, role: :school_admin, school_id: 31),
          Actor.new(user_id: 4, role: :team, team_role: "admin"), nil ].each do |actor|
          assert_equal :forbidden, @policy.call(actor:).code, actor&.role.inspect
        end
      end
    end
  end
end
