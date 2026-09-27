require "test_helper"

module Policies
  module Identity
    class UpdateSelfPolicyTest < ActiveSupport::TestCase
      def target = Entities::Identity::User.new(id: 3, role: "teacher")

      test "soi-même seulement" do
        assert UpdateSelfPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 3, role: :teacher), target:).success?
        assert_equal :forbidden, UpdateSelfPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 4, role: :team), target:).code
        assert_equal :forbidden, UpdateSelfPolicy.new.call(actor: nil, target:).code
      end
    end
  end
end
