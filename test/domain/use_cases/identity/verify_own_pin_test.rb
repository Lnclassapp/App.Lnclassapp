require "test_helper"

module UseCases
  module Identity
    class VerifyOwnPinTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 27, 12)
      Clock = Data.define(:now)

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        attr_reader :checked

        def initialize(user) = (@user, @checked = user, 0)

        def authenticate(contact:, pin:)
          @checked += 1
          @user if contact == @user.contact && pin == "2468"
        end
      end

      class FakeAttempts
        include Ports::Identity::LoginAttemptRepositoryPort

        attr_reader :records, :asked

        def initialize(count:, last_failed_at:) = (@failures, @records = Failures.new(count:, last_failed_at:), [])

        def consecutive_failures(contact:, kind:)
          @asked = { contact:, kind: }
          @failures
        end

        def record(**attributes) = @records << attributes
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :entries

        def initialize = @entries = []
        def record(**entry) = @entries << entry
      end

      setup do
        @user = Entities::Identity::User.new(id: 3, contact: "0701020304", role: "student")
        @users = FakeUsers.new(@user)
        @audit = FakeAudit.new
      end

      def verify(pin, failures: 0, last_failed_at: nil, actor: Entities::Identity::Actor.new(user_id: 3, role: :student))
        @attempts = FakeAttempts.new(count: failures, last_failed_at:)
        VerifyOwnPin.new(users: @users, login_attempts: @attempts, audit_log: @audit, policy: Policies::Identity::UpdateSelfPolicy.new,
                         clock: Clock.new(NOW))
                    .call(actor:, user: @user, pin:, ip: "1.2.3.4")
      end

      test "the right PIN succeeds and is recorded as a sign-in success, on the counter of the sign-in" do
        assert verify("2468").success?

        assert_equal({ contact: "0701020304", kind: Authenticate::KIND }, @attempts.asked)
        assert_equal [ { contact: "0701020304", user_id: 3, ip: "1.2.3.4", succeeded: true, kind: "pin", at: NOW } ], @attempts.records
        assert_empty @audit.entries
      end

      test "another account is forbidden, before any PIN is checked" do
        result = verify("2468", actor: Entities::Identity::Actor.new(user_id: 4, role: :student))

        assert_equal :forbidden, result.code
        assert_equal 0, @users.checked
        assert_empty @attempts.records
      end

      test "a wrong PIN is invalid and counts as a failed sign-in" do
        result = verify("1357")

        assert_equal [ :invalid, { current_pin: [ :incorrect ] } ], [ result.code, result.errors ]
        assert_equal [ [ false, 3 ] ], @attempts.records.map { it.values_at(:succeeded, :user_id) }
        assert_empty @audit.entries
      end

      test "the wrong PIN that reaches the threshold locks the account and writes it in the audit log" do
        result = verify("1357", failures: 4, last_failed_at: NOW - 1.hour)

        assert_equal [ :locked, { retry_after: 15.minutes } ], [ result.code, result.errors ]
        assert_equal [ false ], @attempts.records.map { it[:succeeded] }
        assert_equal [ [ "login.locked", "User", 3, { kind: "pin", failures: 5 } ] ],
                     @audit.entries.map { it.values_at(:action, :subject_type, :subject_id, :metadata) }
      end

      test "the twentieth failure locks until recovery" do
        assert_equal :until_recovery, verify("1357", failures: 19, last_failed_at: NOW - 2.hours).errors[:retry_after]
      end

      test "a failure after an elapsed lockout locks again, as the sign-in does, without a new audit entry" do
        result = verify("1357", failures: 6, last_failed_at: NOW - 16.minutes)

        assert_equal [ :locked, { retry_after: 15.minutes } ], [ result.code, result.errors ]
        assert_empty @audit.entries
      end

      test "an account already locked is refused without checking the PIN, even a right one" do
        result = verify("2468", failures: 5, last_failed_at: NOW - 1.minute)

        assert_equal [ :locked, { retry_after: 14.minutes } ], [ result.code, result.errors ]
        assert_equal 0, @users.checked
        assert_empty @attempts.records
      end
    end
  end
end
