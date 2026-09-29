require "test_helper"

module Repositories
  module School
    # ADR-0065 : un compte de direction est rattaché à un seul établissement, par l'équipe qui l'a invité.
    class StaffRepositoryTest < ActiveSupport::TestCase
      setup { @repository = StaffRepository.new }

      test "attach writes the attachment of the direction account, dated" do
        school = create_school
        admin = create_user(role: "school_admin")
        inviter = create_team_member
        at = Time.utc(2026, 9, 29, 10)

        assert @repository.attach(user_id: admin.id, school_id: school.id, invited_by_id: inviter.id, at:)
        assert_equal [ school.id, inviter.id, at ], Orm::SchoolStaff.find_by!(user_id: admin.id).then { [ it.school_id, it.invited_by_id, it.created_at ] }
      end

      test "a second attachment of the same account is refused" do
        admin = create_school_admin

        assert_raises(ActiveRecord::RecordNotUnique) do
          @repository.attach(user_id: admin.id, school_id: create_school.id, invited_by_id: nil, at: Time.current)
        end
      end
    end
  end
end
