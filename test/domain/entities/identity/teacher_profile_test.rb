require "test_helper"

module Entities
  module Identity
    class TeacherProfileTest < ActiveSupport::TestCase
      test "l'onboarding est un état persisté" do
        assert TeacherProfile.new(user_id: 1, material_id: 2, onboarding_completed_at: Time.utc(2026, 9, 25)).onboarded?
        assert_not TeacherProfile.new(user_id: 1, material_id: 2, onboarding_completed_at: nil).onboarded?
      end
    end
  end
end
