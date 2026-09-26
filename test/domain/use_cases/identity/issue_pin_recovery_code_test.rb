require "test_helper"

module UseCases
  module Identity
    # ID-15, ADR-0032: a teacher for a student of an active classroom they teach, the team for any other account; an
    # 8-digit code valid 15 minutes, only its digest stored, audited with issuer and target, the clear code returned once.
    class IssuePinRecoveryCodeTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 26, 10)
      KEY = "k" * 32
      Clock = Data.define(:now)
      TEACHER = Entities::Identity::Actor.new(user_id: 5, role: :teacher, school_id: 1)
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      STUDENT = Entities::Identity::User.new(id: 20, public_id: "stu20", role: "student", first_name: "Awa", last_name: "Koné")
      COLLEAGUE = Entities::Identity::User.new(id: 21, public_id: "tea21", role: "teacher", first_name: "Yao", last_name: "N'Guessan")
      MEMBER = Entities::Identity::User.new(id: 7, public_id: "team7", role: "team", team_role: "content")

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(users) = @users = users.index_by(&:public_id)
        def find_by_public_id(public_id:) = @users[public_id]
      end

      # memberships : { student_id => Membership }
      class FakeMemberships
        include Ports::Classroom::MembershipRepositoryPort

        attr_reader :reads

        def initialize(memberships)
          @memberships = memberships
          @reads = 0
        end

        def primary_for(student_id:)
          @reads += 1
          @memberships[student_id]
        end
      end

      class FakeTeachings
        include Ports::Classroom::TeachingRepositoryPort

        def initialize(classroom_ids) = @classroom_ids = classroom_ids
        def classroom_ids_for(teacher_id:) = @classroom_ids.fetch(teacher_id, [])
      end

      class FakePinRecoveries
        include Ports::Identity::PinRecoveryRepositoryPort

        attr_reader :issued

        def issue(**code) = (@issued ||= []) << code
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def record(**event) = (@events ||= []) << event
      end

      def membership(classroom_id: 3, status: "active")
        Entities::Classroom::Membership.new(classroom_id:, student_id: STUDENT.id, primary: true, joined_at: NOW,
                                            left_at: nil, classroom_status: status)
      end

      def issue(actor: TEACHER, target: STUDENT.public_id, memberships: { STUDENT.id => membership }, taught: { 5 => [ 3 ] })
        @memberships = FakeMemberships.new(memberships)
        @pin_recoveries = FakePinRecoveries.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        IssuePinRecoveryCode.new(users: FakeUsers.new([ STUDENT, COLLEAGUE, MEMBER ]), memberships: @memberships,
                                 teachings: FakeTeachings.new(taught), pin_recoveries: @pin_recoveries, audit_log: @audit,
                                 transaction: @transaction, policy: Policies::Identity::IssuePinRecoveryCodePolicy.new,
                                 digest_key: KEY, clock: Clock.new(NOW))
                            .call(actor:, target_public_id: target)
      end

      test "a teacher issues a code for a student of an active classroom they teach: digest only, 15 min, audited" do
        result = issue

        assert result.success?
        code = result.value.code
        assert_match(/\A\d{8}\z/, code)
        assert_equal NOW + 15.minutes, result.value.expires_at
        assert_equal STUDENT, result.value.user
        assert_equal [ { user_id: 20, issued_by_id: 5, code_digest: Entities::Identity::SecretDigest.hmac(code, key: KEY),
                         expires_at: NOW + 15.minutes, at: NOW } ], @pin_recoveries.issued
        assert_equal [ { action: "pin.recovery_code_issued", actor_id: 5, at: NOW, subject_type: "User", subject_id: 20 } ],
                     @audit.events
        assert_equal 1, @transaction.calls
      end

      test "the code never leaves in the journal" do
        result = issue

        assert_not_includes @audit.events.inspect, result.value.code
      end

      test "two codes are drawn independently" do
        codes = Array.new(5) { issue.value.code }

        assert_operator codes.uniq.size, :>, 1
      end

      test "the team issues a code for any account but its own, without reading any classroom" do
        [ STUDENT, COLLEAGUE ].each do |target|
          assert issue(actor: TEAM, target: target.public_id).success?
          assert_equal 0, @memberships.reads
        end
      end

      test "a teacher is refused for a student of another classroom, of an archived classroom, or without classroom" do
        [ { taught: { 5 => [ 4 ] } }, { memberships: { STUDENT.id => membership(status: "archived") } },
          { memberships: {} }, { taught: {} } ].each do |facts|
          result = issue(**facts)

          assert_equal :forbidden, result.code
          assert_nil @pin_recoveries.issued
          assert_nil @audit.events
        end
      end

      test "a teacher is refused for another adult without reading any classroom" do
        assert_equal :forbidden, issue(target: COLLEAGUE.public_id).code
        assert_equal 0, @memberships.reads
      end

      test "the team is refused on its own account, a student and the visitor everywhere" do
        assert_equal :forbidden, issue(actor: TEAM, target: MEMBER.public_id).code
        assert_equal :forbidden, issue(actor: Entities::Identity::Actor.new(user_id: 20, role: :student)).code
        assert_equal :forbidden, issue(actor: nil).code
        assert_nil @pin_recoveries.issued
        assert_equal 0, @transaction.calls
      end

      test "an unknown account is not found, before any write" do
        result = issue(target: "inconnu")

        assert_equal :not_found, result.code
        assert_nil @pin_recoveries.issued
      end
    end
  end
end
