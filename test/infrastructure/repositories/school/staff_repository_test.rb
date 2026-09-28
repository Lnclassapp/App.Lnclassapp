require "test_helper"

module Repositories
  module School
    # ADR-0044, ADR-0066 §4.5: the direction of a school (school_staffs); one active school per member, one active principal
    # per school, both held by partial unique indexes.
    class StaffRepositoryTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 29, 9)

      setup do
        @repository = StaffRepository.new
        @school = create_school
        @team = create_team_member
      end

      def attach(user, position: "censor", school: @school, invited_by: @team)
        @repository.attach(user_id: user.id, school_id: school.id, position:, invited_by_id: invited_by&.id, at: NOW)
      end

      test "attaches a school_admin to a school with a position, and gives back the member" do
        user = create_user(role: "school_admin")

        result = attach(user, position: "educator")

        assert result.success?
        member = result.value
        assert_instance_of Entities::School::StaffMember, member
        assert_equal [ user.id, @school.id, "educator", @team.id, NOW, nil ],
                     [ member.user_id, member.school_id, member.position, member.invited_by_id, member.joined_at, member.left_at ]
        assert_equal Orm::SchoolStaff.find_by!(user:).id, member.id
        assert member.active?
        assert_not member.principal?
      end

      test "an account that is not school_admin raises: no check can read users" do
        %w[student teacher team].each do |role|
          assert_raises(ArgumentError, role) { attach(create_user(role:)) }
        end
        assert_raises(ArgumentError) { @repository.attach(user_id: 0, school_id: @school.id, position: "censor", invited_by_id: nil, at: NOW) }
        assert_equal 0, Orm::SchoolStaff.count
      end

      test "a second active school is a conflict other_school; a second active principal a conflict principal_taken" do
        member = create_user(role: "school_admin")
        attach(member, position: "principal")

        other = attach(member, school: create_school)
        taken = attach(create_user(role: "school_admin"), position: "principal")

        assert_equal [ :conflict, { base: [ :other_school ] } ], [ other.code, other.errors ]
        assert_equal [ :conflict, { position: [ :principal_taken ] } ], [ taken.code, taken.errors ]
        assert_equal 1, Orm::SchoolStaff.count
      end

      # The unique index refuses inside a savepoint: the transaction of the caller stays usable.
      test "a conflict leaves the caller's transaction usable" do
        member = create_user(role: "school_admin")
        attach(member)

        Orm::SchoolStaff.transaction do
          assert attach(member, school: create_school).failure?
          assert_equal 1, Orm::SchoolStaff.count
        end
      end

      test "find_active reads the active member of that school only, by the public id of the account" do
        member = create_user(role: "school_admin")
        attach(member, position: "principal")
        departed = create_user(role: "school_admin")
        @repository.detach(id: attach(departed).value.id, at: NOW)

        found = @repository.find_active(user_public_id: member.public_id, school_id: @school.id)

        assert_equal [ member.id, "principal" ], [ found.user_id, found.position ]
        assert found.principal?
        assert_nil @repository.find_active(user_public_id: member.public_id, school_id: create_school.id)
        assert_nil @repository.find_active(user_public_id: departed.public_id, school_id: @school.id)
        assert_nil @repository.find_active(user_public_id: "inconnu", school_id: @school.id)
      end

      test "principal_active? is true only while an active principal holds the school" do
        assert_not @repository.principal_active?(school_id: @school.id)
        attach(create_user(role: "school_admin"), position: "censor")
        assert_not @repository.principal_active?(school_id: @school.id)

        principal = attach(create_user(role: "school_admin"), position: "principal").value
        assert @repository.principal_active?(school_id: @school.id)
        assert_not @repository.principal_active?(school_id: create_school.id)

        @repository.detach(id: principal.id, at: NOW)
        assert_not @repository.principal_active?(school_id: @school.id)
      end

      test "detach closes the membership and frees the member and the position" do
        member = create_user(role: "school_admin")
        staff = attach(member, position: "principal").value

        assert_equal true, @repository.detach(id: staff.id, at: NOW)

        assert_equal NOW, Orm::SchoolStaff.find(staff.id).left_at
        assert attach(member, school: create_school).success?
        assert attach(create_user(role: "school_admin"), position: "principal").success?
      end
    end
  end
end
