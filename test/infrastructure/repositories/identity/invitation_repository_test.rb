require "test_helper"

module Repositories
  module Identity
    class InvitationRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = InvitationRepository.new
        @admin = create_team_member
        @expires_at = 72.hours.from_now.change(usec: 0)
      end

      def invite(contact: "0701020304")
        @repository.create(kind: "team", contact:, team_role: "content", invited_by_id: @admin.id,
                           token_digest: SecureRandom.hex(32), expires_at: @expires_at)
      end

      test "create stores a pending invitation" do
        result = invite

        assert result.success?
        assert_equal [ "team", "0701020304", "content", @admin.id, @expires_at ],
                     [ result.value.kind, result.value.contact, result.value.team_role, result.value.invited_by_id, result.value.expires_at ]
        assert_equal :pending, result.value.status(now: Time.current)
      end

      test "create stores a school staff invitation with its school and position" do
        school = create_school

        result = @repository.create(kind: "school_staff", contact: "0701020305", team_role: nil, invited_by_id: @admin.id,
                                    token_digest: SecureRandom.hex(32), expires_at: @expires_at,
                                    school_id: school.id, position: "censor")

        assert result.success?
        assert_equal [ "school_staff", school.id, "censor", nil ],
                     [ result.value.kind, result.value.school_id, result.value.position, result.value.team_role ]
      end

      test "a second pending invitation for the same contact is a conflict" do
        invite

        Repositories::Shared::Transaction.new.call do
          result = invite

          assert_equal :conflict, result.code
          assert_equal({ contact: [ :already_invited ] }, result.errors)
          assert_equal 1, Orm::Invitation.count
        end
      end

      test "find_by_token_digest finds the invitation, or nil" do
        invitation = create_invitation(token: "jeton")

        assert_equal invitation.id, @repository.find_by_token_digest(token_digest: secret_digest("jeton")).id
        assert_nil @repository.find_by_token_digest(token_digest: secret_digest("autre"))
      end

      test "mark_accepted records the account" do
        invitation = create_invitation
        member = create_team_member
        at = Time.current.change(usec: 0)

        assert @repository.mark_accepted(id: invitation.id, user_id: member.id, at:)

        found = @repository.find_by_token_digest(token_digest: invitation.token_digest)
        assert_equal [ at, member.id, :accepted ], [ found.accepted_at, found.accepted_user_id, found.status(now: at) ]
      end
    end
  end
end
