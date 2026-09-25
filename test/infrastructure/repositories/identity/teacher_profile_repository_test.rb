require "test_helper"

module Repositories
  module Identity
    class TeacherProfileRepositoryTest < ActiveSupport::TestCase
      setup { @repository = TeacherProfileRepository.new }

      test "find_by_user_id maps the profile" do
        teacher = create_teacher(onboarded: false)

        profile = @repository.find_by_user_id(user_id: teacher.id)

        assert_equal teacher.id, profile.user_id
        assert_equal teacher.teacher_profile.material_id, profile.material_id
        assert_not profile.onboarded?
      end

      test "a user without a profile is nil" do
        assert_nil @repository.find_by_user_id(user_id: create_student.id)
      end

      test "complete_onboarding is idempotent" do
        teacher = create_teacher(onboarded: false)
        first = 2.days.ago.change(usec: 0)

        assert @repository.complete_onboarding(user_id: teacher.id, at: first)
        assert @repository.complete_onboarding(user_id: teacher.id, at: Time.current)

        assert_equal first, @repository.find_by_user_id(user_id: teacher.id).onboarding_completed_at
      end
    end
  end
end
