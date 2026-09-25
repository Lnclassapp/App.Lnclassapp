require "test_helper"

module UseCases
  module Identity
    class ResetPinWithCodeTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        attr_reader :new_pin

        def find_by_contact(contact:)
          Entities::Identity::User.new(id: 1, role: "student", contact:) if contact == "0701020304"
        end

        def update_pin(user_id:, pin:) = @new_pin = pin
      end

      # Révoque au 5e échec, comme le repository.
      class FakeRecoveries
        include Ports::Identity::PinRecoveryRepositoryPort

        attr_reader :consumed, :failures

        def initialize(code)
          @code = code
          @failures = 0
        end

        def active_for(user_id:) = @code

        def record_failure(id:, at:)
          @failures += 1
          @code = @code.with(failed_attempts: @failures, revoked_at: (at if @failures >= Entities::Identity::PinRecoveryCode::MAX_FAILED_ATTEMPTS))
          @failures
        end

        def consume(id:, at:) = @consumed = id
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :destroyed_for

        def destroy_all_for(user_id:) = @destroyed_for = user_id
      end

      class FakeAttempts
        include Ports::Identity::LoginAttemptRepositoryPort

        attr_reader :cleared

        def clear_failures(contact:) = @cleared = contact
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :actions

        def record(action:, **) = (@actions ||= []) << action
      end

      class FakeTransaction
        include Ports::Shared::TransactionPort

        attr_reader :opened

        def call
          @opened = true
          yield
        end
      end

      def recovery_code(**overrides)
        Entities::Identity::PinRecoveryCode.new(id: 3, user_id: 1, code_digest: Entities::Identity::SecretDigest.hmac("12345678", key: "key"),
                                                expires_at: NOW + 10.minutes, **overrides)
      end

      setup do
        @users = FakeUsers.new
        @sessions = FakeSessions.new
        @attempts = FakeAttempts.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        @recoveries = FakeRecoveries.new(recovery_code)
      end

      def reset(code: "12345678", contact: "0701020304", pin: "1357", pin_confirmation: pin)
        dto = Dtos::Identity::PinResetInput.new(contact:, code:, pin:, pin_confirmation:, ip: "1.2.3.4")
        ResetPinWithCode.new(users: @users, pin_recoveries: @recoveries, sessions: @sessions, login_attempts: @attempts,
                             audit_log: @audit, transaction: @transaction, digest_key: "key", clock: Clock.new(NOW)).call(dto:)
      end

      test "a right code changes the PIN, consumes the code, ends every session and lifts the lockout, in a transaction" do
        assert reset(code: "1234 5678").success?
        assert_equal "1357", @users.new_pin
        assert_equal 3, @recoveries.consumed
        assert_equal 1, @sessions.destroyed_for
        assert_equal "0701020304", @attempts.cleared
        assert_equal [ "pin.reset" ], @audit.actions
        assert @transaction.opened
      end

      test "unknown number, missing, revoked or wrong code: the same invalid" do
        results = [ reset(contact: "0501020304") ]
        @recoveries = FakeRecoveries.new(nil)
        results << reset
        @recoveries = FakeRecoveries.new(recovery_code(revoked_at: NOW))
        results << reset
        @recoveries = FakeRecoveries.new(recovery_code)
        results << reset(code: "87654321")

        assert_equal [ :invalid ], results.map(&:code).uniq
        assert_equal [ { base: [ :invalid_recovery ] } ], results.map(&:errors).uniq
        assert_equal 1, @recoveries.failures
        assert_nil @users.new_pin
      end

      test "an expired code is expired" do
        @recoveries = FakeRecoveries.new(recovery_code(expires_at: NOW))

        assert_equal :expired, reset.code
      end

      test "5 failures revoke the code: the right code is refused afterwards" do
        5.times { reset(code: "87654321") }

        assert_equal :invalid, reset.code
        assert_nil @users.new_pin
      end

      test "a malformed input is invalid with its fields and opens no transaction" do
        result = reset(pin: "1357", pin_confirmation: "2468")

        assert_equal :invalid, result.code
        assert result.errors.key?(:pin_confirmation)
        assert_nil @transaction.opened
      end
    end
  end
end
