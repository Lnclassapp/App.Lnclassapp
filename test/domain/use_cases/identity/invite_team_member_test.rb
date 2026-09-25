require "test_helper"

module UseCases
  module Identity
    # F-16, ADR-0038: only a team admin invites; one pending invitation per number; the clear token leaves once.
    class InviteTeamMemberTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      KEY = "k" * 32
      Clock = Data.define(:now)
      ADMIN = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "admin")

      # Like the partial unique index: a number that already waits for an invitation is a conflict.
      class FakeInvitations
        include Ports::Identity::InvitationRepositoryPort

        attr_reader :created

        def initialize(pending: [])
          @pending = pending
          @created = []
        end

        def create(kind:, contact:, team_role:, invited_by_id:, token_digest:, expires_at:, school_id: nil, position: nil)
          return Shared::Result.failure(:conflict, errors: { contact: [ :already_invited ] }) if @pending.include?(contact)

          @created << { kind:, contact:, team_role:, invited_by_id:, token_digest:, expires_at:, school_id:, position: }
          Shared::Result.success(Entities::Identity::Invitation.new(id: 31, kind:, contact:, team_role:, invited_by_id:, expires_at:))
        end
      end

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(contacts: [])
          @contacts = contacts
        end

        def find_by_contact(contact:)
          return unless @contacts.include?(contact)

          Entities::Identity::User.new(id: 3, contact:, role: "teacher")
        end
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def record(**event) = (@events ||= []) << event
      end

      def invite(contact: "07 00 00 00 09", team_role: "content", actor: ADMIN, pending: [], accounts: [])
        @invitations = FakeInvitations.new(pending:)
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        InviteTeamMember.new(invitations: @invitations, users: FakeUsers.new(contacts: accounts), audit_log: @audit,
                             transaction: @transaction, policy: Policies::Identity::InviteTeamPolicy.new, digest_key: KEY,
                             clock: Clock.new(NOW))
                        .call(actor:, dto: Dtos::Identity::TeamInvitationInput.new(contact:, team_role:))
      end

      def contact_errors(raw) = Dtos::Identity::TeamInvitationInput.new(contact: raw).tap(&:validate).errors.details[:contact]

      test "an admin invites a number: 72 h, only the token digest stored, audited, the clear token returned once" do
        result = invite

        assert result.success?
        token = result.value.token
        assert_match(/\A[1-9A-HJ-NP-Za-km-z]{32}\z/, token)
        assert_equal [ { kind: "team", contact: "0700000009", team_role: "content", invited_by_id: 7,
                         token_digest: Entities::Identity::SecretDigest.hmac(token, key: KEY), expires_at: NOW + 72.hours,
                         school_id: nil, position: nil } ], @invitations.created
        assert_equal 31, result.value.invitation.id
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "invitation.sent", actor_id: 7, at: NOW, subject_type: "Invitation", subject_id: 31,
                         metadata: { team_role: "content" } } ], @audit.events
      end

      test "two invitations never share a token" do
        assert_not_equal invite(contact: "0700000001").value.token, invite(contact: "0700000002").value.token
      end

      test "a content or field member, another role and the visitor are refused, without writing" do
        [ nil, Entities::Identity::Actor.new(user_id: 8, role: :team, team_role: "content"),
          Entities::Identity::Actor.new(user_id: 9, role: :team, team_role: "field"),
          Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 1),
          Entities::Identity::Actor.new(user_id: 4, role: :student) ].each do |actor|
          result = invite(actor:)

          assert_equal :forbidden, result.code
          assert_empty @invitations.created
          assert_nil @audit.events
        end
      end

      test "a blank or malformed number and an unknown role are invalid, before any write" do
        assert_equal %i[contact team_role], invite(contact: " ", team_role: "owner").errors.keys.sort
        assert_equal [ :contact ], invite(contact: "0811223344").errors.keys
        assert_equal [ { error: :blank } ], contact_errors(" ")
        assert_equal [ { error: :invalid } ], contact_errors("0811223344")
        assert_equal :invalid, invite(team_role: nil).code
        assert_empty @invitations.created
        assert_equal 0, @transaction.calls
      end

      test "a number already linked to an account is a conflict on the number" do
        result = invite(accounts: [ "0700000009" ])

        assert_equal :conflict, result.code
        assert_equal({ contact: [ :taken ] }, result.errors)
        assert_empty @invitations.created
      end

      test "a number that already waits for an invitation is a conflict, without audit" do
        result = invite(pending: [ "0700000009" ])

        assert_equal :conflict, result.code
        assert_equal({ contact: [ :already_invited ] }, result.errors)
        assert_nil @audit.events
      end

      test "the typed number is kept for the form" do
        dto = Dtos::Identity::TeamInvitationInput.new(contact: "07 00 00 00 09")

        assert_equal "07 00 00 00 09", dto.raw_contact
        assert_equal "0700000009", dto.contact
        assert_nil Dtos::Identity::TeamInvitationInput.new.raw_contact
      end
    end
  end
end
