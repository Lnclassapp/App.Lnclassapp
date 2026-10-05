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

      test "every method follows the signature of the port" do
        Ports::Identity::InvitationRepositoryPort.instance_methods(false).each do |name|
          assert_equal Ports::Identity::InvitationRepositoryPort.instance_method(name).parameters,
                       InvitationRepository.instance_method(name).parameters, name
        end
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

      test "revoke_expired frees the contact of its expired invitation only" do
        @expires_at = 1.minute.ago.change(usec: 0)
        expired = invite.value
        other = invite(contact: "0701020399").value

        assert_equal 1, @repository.revoke_expired(kind: "team", contact: "0701020304", at: Time.current)
        assert_not_nil Orm::Invitation.find(expired.id).revoked_at
        assert_nil Orm::Invitation.find(other.id).revoked_at
        @expires_at = 72.hours.from_now.change(usec: 0)
        assert invite.success?
        assert_equal 0, @repository.revoke_expired(kind: "team", contact: "0701020304", at: Time.current)
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

      # suites-inscription-direction (2), ADR-0036 §4.
      test "destroy_all_for removes the invitation accepted by the account and every one to its number, not those it sent" do
        admin = create_school_admin
        accepted = create_invitation(kind: "school_staff", contact: admin.contact, accepted_at: 1.day.ago, accepted_user_id: admin.id)
        pending = create_invitation(kind: "team", contact: admin.contact)
        sent = create_invitation(kind: "team", invited_by: admin)
        other = create_invitation(kind: "team")

        assert_equal 2, @repository.destroy_all_for(user_id: admin.id, contact: admin.contact)
        assert_equal [ sent.id, other.id ].sort, Orm::Invitation.where(id: [ accepted, pending, sent, other ].map(&:id)).ids.sort
      end

      test "destroy_all_for of an account whose number is already erased removes only what it accepted" do
        admin = create_school_admin
        create_invitation(kind: "school_staff", contact: admin.contact, accepted_at: 1.day.ago, accepted_user_id: admin.id)
        kept = create_invitation(kind: "team")

        assert_equal 1, @repository.destroy_all_for(user_id: admin.id, contact: nil)
        assert Orm::Invitation.exists?(kept.id)
      end
    end
  end
end
