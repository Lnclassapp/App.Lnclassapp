require "test_helper"

module Repositories
  module Identity
    class RegistrationRepositoryTest < ActiveSupport::TestCase
      setup { @repository = RegistrationRepository.new }

      def person(contact: "0101020304", **attributes)
        Entities::Identity::User.new(last_name: "Koné", first_name: "Awa", gender: "female", contact:, **attributes)
      end

      test "create_student creates a student account" do
        result = @repository.create_student(user: person, pin: "2468")

        assert result.success?
        record = Orm::User.find(result.value.id)
        assert_equal [ "student", "0101020304", nil ], [ record.role, record.contact, record.team_role ]
        assert record.authenticate_pin("2468")
        assert_equal record.public_id, result.value.public_id
      end

      test "create_school_admin creates a direction account, with no attachment (ADR-0077)" do
        result = @repository.create_school_admin(user: person(contact: "0701020304"), pin: "2468")

        assert result.success?
        record = Orm::User.find(result.value.id)
        assert_equal [ "school_admin", nil ], [ record.role, record.school_staff ]
        assert_equal "school_admin", result.value.role
      end

      test "a taken contact is a conflict and leaves the enclosing transaction usable" do
        create_student(contact: "0101020304")

        Repositories::Shared::Transaction.new.call do
          result = @repository.create_student(user: person, pin: "2468")

          assert_equal :conflict, result.code
          assert_equal({ contact: [ :taken ] }, result.errors)
          assert_equal 1, Orm::User.where(contact: "0101020304").count
        end
      end

      test "create_teacher also creates the teacher profile" do
        material = create_material

        result = @repository.create_teacher(user: person(contact: "0501020304"), pin: "2468", material_id: material.id)

        assert_equal "teacher", result.value.role
        profile = Orm::TeacherProfile.find_by!(user_id: result.value.id)
        assert_equal material.id, profile.material_id
        assert_nil profile.onboarding_completed_at
      end

      test "a taken contact creates no teacher profile" do
        create_teacher(contact: "0501020304")

        assert_no_difference "Orm::TeacherProfile.count" do
          assert_equal :conflict, @repository.create_teacher(user: person(contact: "0501020304"), pin: "2468",
                                                             material_id: create_material.id).code
        end
      end

      test "create_from_invitation creates the invited account and accepts the invitation" do
        invitation = create_invitation(contact: "0701020304", team_role: "content")
        at = Time.current.change(usec: 0)

        result = @repository.create_from_invitation(user: person(contact: "0701020304", role: "team", team_role: "content"),
                                                    pin: "2468", invitation_id: invitation.id, at:)

        assert_equal [ "team", "content" ], [ result.value.role, result.value.team_role ]
        invitation.reload
        assert_equal [ at, result.value.id ], [ invitation.accepted_at, invitation.accepted_user_id ]
      end
    end
  end
end
