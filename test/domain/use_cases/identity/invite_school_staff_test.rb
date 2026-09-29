require "test_helper"

module UseCases
  module Identity
    # DS-01, DS-02, ADR-0065: the team invites the management of an active school; no position, one pending invitation
    # per number, the clear token leaves once.
    class InviteSchoolStaffTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 29, 12)
      KEY = "k" * 32
      Clock = Data.define(:now)
      FIELD = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")

      # Like the partial unique index: a number that already waits for an invitation is a conflict, until the expired
      # one is revoked. Pending invitations are { contact => expires_at }.
      class FakeInvitations
        include Ports::Identity::InvitationRepositoryPort

        attr_reader :created, :revocations

        def initialize(pending: {})
          @pending = pending.dup
          @created = []
          @revocations = []
        end

        def revoke_expired(kind:, contact:, at:)
          @revocations << { kind:, contact:, at: }
          expired = @pending.select { |pending_contact, expires_at| pending_contact == contact && expires_at <= at }
          expired.each_key { @pending.delete(it) }
          expired.size
        end

        def create(kind:, contact:, team_role:, invited_by_id:, token_digest:, expires_at:, school_id: nil, position: nil)
          return Shared::Result.failure(:conflict, errors: { contact: [ :already_invited ] }) if @pending.key?(contact)

          @created << { kind:, contact:, team_role:, invited_by_id:, token_digest:, expires_at:, school_id:, position: }
          Shared::Result.success(Entities::Identity::Invitation.new(id: 31, kind:, contact:, school_id:, invited_by_id:, expires_at:))
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

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        def initialize(schools)
          @schools = schools
        end

        def find_by_public_id(public_id:) = @schools.find { it.public_id == public_id }
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def record(**event) = (@events ||= []) << event
      end

      def school(public_id: "bouake", status: "active")
        Entities::School::School.new(id: 2, public_id:, drena_id: 1, name: "Lycée Moderne de Bouaké", school_type: "public",
                                     cycle: "both", status:)
      end

      def invite(contact: "07 00 00 00 09", school_public_id: "bouake", actor: FIELD, schools: [ school ], pending: {}, accounts: [])
        @invitations = FakeInvitations.new(pending:)
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        InviteSchoolStaff.new(invitations: @invitations, users: FakeUsers.new(contacts: accounts), schools: FakeSchools.new(schools),
                              audit_log: @audit, transaction: @transaction, policy: Policies::Identity::InviteSchoolStaffPolicy.new,
                              digest_key: KEY, clock: Clock.new(NOW))
                         .call(actor:, dto: Dtos::Identity::SchoolStaffInvitationInput.new(contact:, school_public_id:))
      end

      test "DS-01: a management invitation for this school, without position, 72 h, audited, the clear token returned once" do
        result = invite

        assert result.success?
        token = result.value.token
        assert_match(/\A[1-9A-HJ-NP-Za-km-z]{32}\z/, token)
        assert_equal [ { kind: "school_staff", contact: "0700000009", team_role: nil, invited_by_id: 7,
                         token_digest: Entities::Identity::SecretDigest.hmac(token, key: KEY), expires_at: NOW + 72.hours,
                         school_id: 2, position: nil } ], @invitations.created
        assert_equal 31, result.value.invitation.id
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "invitation.sent", actor_id: 7, at: NOW, subject_type: "Invitation", subject_id: 31,
                         metadata: { kind: "school_staff", school_id: 2 } } ], @audit.events
      end

      test "DS-02: an inactive or draft school is invalid on the school, before any write" do
        %w[inactive draft].each do |status|
          result = invite(schools: [ school(status:) ])

          assert_equal :invalid, result.code
          assert_equal({ school: [ :inactive ] }, result.errors)
          assert_empty @invitations.created
          assert_equal 0, @transaction.calls
        end
      end

      test "an unknown school is not found" do
        assert_equal :not_found, invite(school_public_id: "ailleurs").code
        assert_empty @invitations.created
      end

      test "DS-02: a number already linked to an account is a conflict on the number" do
        result = invite(accounts: [ "0700000009" ])

        assert_equal :conflict, result.code
        assert_equal({ contact: [ :taken ] }, result.errors)
        assert_empty @invitations.created
      end

      test "a number that already waits for a valid invitation is a conflict, without audit" do
        result = invite(pending: { "0700000009" => NOW + 1.second })

        assert_equal :conflict, result.code
        assert_equal({ contact: [ :already_invited ] }, result.errors)
        assert_nil @audit.events
      end

      test "an expired invitation never accepted is revoked first and no longer blocks a new one" do
        assert invite(pending: { "0700000009" => NOW }).success?
        assert_equal [ { kind: "school_staff", contact: "0700000009", at: NOW } ], @invitations.revocations
      end

      test "a blank or malformed number is invalid, before any write" do
        assert_equal :invalid, invite(contact: " ").code
        assert_equal [ :contact ], invite(contact: "0811223344").errors.keys
        assert_equal [ { error: :blank } ], Dtos::Identity::SchoolStaffInvitationInput.new(contact: " ").tap(&:validate).errors.details[:contact]
        dto = Dtos::Identity::SchoolStaffInvitationInput.new(contact: "08 11 22 33 44").tap(&:validate)
        assert_equal [ { error: :invalid } ], dto.errors.details[:contact]
        assert_equal "08 11 22 33 44", dto.raw_contact
        assert_empty @invitations.created
      end

      test "DS-04: a content member, a school admin, a teacher and the visitor are refused, without reading the school" do
        [ nil, Entities::Identity::Actor.new(user_id: 8, role: :team, team_role: "content"),
          Entities::Identity::Actor.new(user_id: 9, role: :school_admin, school_id: 2),
          Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 2) ].each do |actor|
          result = invite(actor:, schools: [])

          assert_equal :forbidden, result.code
          assert_empty @invitations.created
          assert_nil @audit.events
        end
      end
    end
  end
end
