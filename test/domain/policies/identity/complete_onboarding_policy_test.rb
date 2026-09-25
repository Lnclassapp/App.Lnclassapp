require "test_helper"

module Policies
  module Identity
    class CompleteOnboardingPolicyTest < ActiveSupport::TestCase
      test "un enseignant seulement" do
        assert CompleteOnboardingPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 1)).success?
        assert_equal :forbidden, CompleteOnboardingPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 4, role: :team)).code
        assert_equal :forbidden, CompleteOnboardingPolicy.new.call(actor: Entities::Identity::Actor.new(user_id: 5, role: :student)).code
        assert_equal :forbidden, CompleteOnboardingPolicy.new.call(actor: nil).code
      end
    end
  end
end
