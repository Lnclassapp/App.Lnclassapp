require "test_helper"

module UseCases
  module Identity
    # F-16, ADR-0028 (no policy: the visitor holds the link), ADR-0038: the link creates one team account, once.
    # DS-03, ADR-0065: a management link creates one school admin account, attached to its school alone.
    class AcceptInvitationTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      KEY = "k" * 32
      TOKEN = "T" * 32
      Clock = Data.define(:now)

      class FakeInvitations
        include Ports::Identity::InvitationRepositoryPort

        attr_reader :accepted

        def initialize(invitation)
          @invitation = invitation
          @accepted = []
        end

        def find_by_token_digest(token_digest:)
          @invitation if token_digest == Entities::Identity::SecretDigest.hmac(TOKEN, key: KEY)
        end

        def mark_accepted(id:, user_id:, at:)
          @accepted << { id:, user_id:, at: }
          true
        end
      end

      # Like the unique index on users.contact.
      class FakeRegistrations
        include Ports::Identity::RegistrationRepositoryPort

        attr_reader :created

        def initialize(taken: false)
          @taken = taken
          @created = []
        end

        def create_from_invitation(user:, pin:, invitation_id:, at:)
          return Shared::Result.failure(:conflict, errors: { contact: [ :taken ] }) if @taken

          user.id = 44
          @created << { user:, pin:, invitation_id:, at: }
          Shared::Result.success(user)
        end
      end

      class FakeStaffs
        include Ports::School::StaffRepositoryPort

        attr_reader :attached

        def attach(user_id:, school_id:, invited_by_id:, at:)
          (@attached ||= []) << { user_id:, school_id:, invited_by_id:, at: }
          true
        end
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def record(**event) = (@events ||= []) << event
      end

      def invitation(kind: "team", **attributes)
        staff = { school_id: 2 } if kind == "school_staff"
        Entities::Identity::Invitation.new(id: 31, kind:, contact: "0700000009", team_role: ("content" if kind == "team"),
                                           invited_by_id: 7, expires_at: NOW + 1.hour, **staff.to_h, **attributes)
      end

      def use_case(invitation: self.invitation, taken: false)
        @invitations = FakeInvitations.new(invitation)
        @registrations = FakeRegistrations.new(taken:)
        @staffs = FakeStaffs.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        AcceptInvitation.new(invitations: @invitations, registrations: @registrations, staffs: @staffs, audit_log: @audit,
                             transaction: @transaction, digest_key: KEY, clock: Clock.new(NOW))
      end

      def form(**overrides)
        Dtos::Identity::InvitationAcceptanceInput.new(last_name: " Koné ", first_name: "Awa  Marie", gender: "female",
                                                      pin: "4821", pin_confirmation: "4821", **overrides)
      end

      test "the link creates a team account with the invited role and number, marks it accepted, audited" do
        result = use_case.call(token: TOKEN, dto: form)

        assert result.success?
        created = @registrations.created.sole
        user = created[:user]
        assert_equal [ "Koné", "Awa Marie", "0700000009", "female", "team", "content" ],
                     [ user.last_name, user.first_name, user.contact, user.gender, user.role, user.team_role ]
        assert_equal({ pin: "4821", invitation_id: 31, at: NOW }, created.except(:user))
        assert_equal user, result.value
        assert_equal [ { id: 31, user_id: 44, at: NOW } ], @invitations.accepted
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "invitation.accepted", actor_id: 44, at: NOW, subject_type: "Invitation", subject_id: 31,
                         metadata: { team_role: "content" } } ], @audit.events
        assert_nil @staffs.attached
      end

      test "DS-03: a management link creates a school admin, without team role, attached to its school in the same transaction" do
        result = use_case(invitation: invitation(kind: "school_staff")).call(token: TOKEN, dto: form)

        assert result.success?
        user = @registrations.created.sole[:user]
        assert_equal [ "Koné", "Awa Marie", "0700000009", "female", "school_admin", nil ],
                     [ user.last_name, user.first_name, user.contact, user.gender, user.role, user.team_role ]
        assert_equal [ { user_id: 44, school_id: 2, invited_by_id: 7, at: NOW } ], @staffs.attached
        assert_equal [ { id: 31, user_id: 44, at: NOW } ], @invitations.accepted
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "invitation.accepted", actor_id: 44, at: NOW, subject_type: "Invitation", subject_id: 31,
                         metadata: { kind: "school_staff", school_id: 2 } } ], @audit.events
      end

      test "check finds a pending management invitation" do
        assert_equal 2, use_case(invitation: invitation(kind: "school_staff")).check(token: TOKEN).value.school_id
      end

      test "the bootstrap invitation, invited by nobody, gives an admin" do
        assert_equal "admin", use_case(invitation: invitation(team_role: "admin", invited_by_id: nil))
                                .call(token: TOKEN, dto: form).value.team_role
      end

      test "an unknown token is not found" do
        assert_equal :not_found, use_case.call(token: "X" * 32, dto: form).code
        assert_equal :not_found, use_case.check(token: "").code
        assert_empty @registrations.created
      end

      test "an expired, accepted or revoked link has expired, even with an invalid form" do
        [ { expires_at: NOW }, { accepted_at: NOW - 1.hour, accepted_user_id: 40 }, { revoked_at: NOW - 1.hour } ].each do |state|
          result = use_case(invitation: invitation(**state)).call(token: TOKEN, dto: form(pin: ""))

          assert_equal :expired, result.code
          assert_empty @registrations.created
          assert_equal 0, @transaction.calls
        end
      end

      test "check finds a pending invitation and reports an expired one, without writing" do
        assert_equal 31, use_case.check(token: TOKEN).value.id
        assert_equal :expired, use_case(invitation: invitation(expires_at: NOW - 1.second)).check(token: TOKEN).code
        assert_empty @registrations.created
      end

      test "an invalid form is refused field by field" do
        result = use_case.call(token: TOKEN, dto: form(last_name: "", gender: "other", pin: "12a4", pin_confirmation: "1234"))

        assert_equal :invalid, result.code
        assert_equal %i[last_name gender pin pin_confirmation], result.errors.keys
        assert_empty @registrations.created
      end

      test "a number that got an account meanwhile is a conflict for the whole form, without audit" do
        [ invitation, invitation(kind: "school_staff") ].each do |pending|
          result = use_case(invitation: pending, taken: true).call(token: TOKEN, dto: form)

          assert_equal :conflict, result.code
          assert_equal({ base: [ :contact_taken ] }, result.errors)
          assert_empty @invitations.accepted
          assert_nil @staffs.attached
          assert_nil @audit.events
        end
      end
    end
  end
end
