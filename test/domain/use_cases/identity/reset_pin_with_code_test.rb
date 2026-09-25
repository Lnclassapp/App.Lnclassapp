require "test_helper"

module UseCases
  module Identity
    class ResetPinWithCodeTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        attr_reader :new_pin

        def find_by_contact(contact:) = (Entities::Identity::User.new(id: 1, role: "student", contact:) if contact == "0701020304")
        def update_pin(user_id:, pin:) = @new_pin = pin
      end

      # Rejoue la révocation au 5e échec, comme le repository.
      class FakeRecoveries
        include Ports::Identity::PinRecoveryRepositoryPort

        attr_reader :consumed

        def initialize(code) = @code = code
        def active_for(user_id:) = @code

        def record_failure(id:, at:)
          @code = @code.with(failed_attempts: @code.failed_attempts + 1)
          @code.failed_attempts
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

        def call = yield
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
        @recoveries = FakeRecoveries.new(recovery_code)
      end

      def reset(code: "12345678", contact: "0701020304", pin: "1357", pin_confirmation: pin)
        dto = Dtos::Identity::PinResetInput.new(contact:, code:, pin:, pin_confirmation:, ip: "1.2.3.4")
        ResetPinWithCode.new(users: @users, pin_recoveries: @recoveries, sessions: @sessions, login_attempts: @attempts,
                             audit_log: @audit, transaction: FakeTransaction.new, digest_key: "key", clock: Clock.new(NOW)).call(dto:)
      end

      test "un code juste change le PIN, consomme le code, coupe les sessions et lève le verrouillage" do
        assert reset.success?
        assert_equal "1357", @users.new_pin
        assert_equal 3, @recoveries.consumed
        assert_equal 1, @sessions.destroyed_for
        assert_equal "0701020304", @attempts.cleared
        assert_equal [ "pin.reset" ], @audit.actions
      end

      test "numéro inconnu, code absent, révoqué ou faux : même :invalid" do
        results = [ reset(contact: "0501020304") ]
        @recoveries = FakeRecoveries.new(nil)
        results << reset
        @recoveries = FakeRecoveries.new(recovery_code(revoked_at: NOW))
        results << reset
        @recoveries = FakeRecoveries.new(recovery_code)
        results << reset(code: "87654321")

        assert_equal [ :invalid ], results.map(&:code).uniq
        assert_equal [ { base: [ :invalid_recovery ] } ], results.map(&:errors).uniq
        assert_nil @users.new_pin
      end

      test "un code périmé est :expired" do
        @recoveries = FakeRecoveries.new(recovery_code(expires_at: NOW))

        assert_equal :expired, reset.code
      end

      test "5 échecs révoquent le code : le bon code est ensuite refusé" do
        5.times { reset(code: "87654321") }

        assert_equal :invalid, reset.code
        assert_nil @users.new_pin
      end

      test "une saisie mal formée est :invalid avec ses champs" do
        result = reset(pin: "1357", pin_confirmation: "2468")

        assert_equal :invalid, result.code
        assert result.errors.key?(:pin_confirmation)
      end
    end
  end
end
