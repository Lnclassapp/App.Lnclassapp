require "test_helper"

module UseCases
  module Identity
    class VerifySecondFactorTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def find(id:) = Entities::Identity::User.new(id:, role: "team", team_role: "admin", contact: "0701020304")
      end

      # Un pas n'est accepté qu'une fois, comme dans le repository.
      class FakeSecondFactors
        include Ports::Identity::SecondFactorRepositoryPort

        def initialize
          @backup_digests = [ Entities::Identity::SecretDigest.hmac("abcDEF2345", key: "key") ]
          @used_steps = []
        end

        def verify_code(user_id:, code:, now:)
          return if code != "123456" || @used_steps.include?(42)

          @used_steps << 42
          42
        end

        def consume_backup_code(user_id:, code_digest:, at:) = !@backup_digests.delete(code_digest).nil?
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :verified

        def mark_second_factor_verified(id:, at:) = @verified = id
      end

      class FakeAttempts
        include Ports::Identity::LoginAttemptRepositoryPort

        attr_reader :records

        def initialize(count) = (@count, @records = count, [])
        def consecutive_failures(contact:, kind:) = Failures.new(count: @count, last_failed_at: NOW - 1.minute)
        def record(**attributes) = @records << attributes
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :entries

        def initialize = @entries = []
        def record(**entry) = @entries << entry
      end

      setup { @second_factors = FakeSecondFactors.new }

      def session(verified_at: nil)
        Entities::Identity::SessionState.new(id: 5, user_id: 9, role: "team", created_at: nil, last_seen_at: nil,
                                             second_factor_verified_at: verified_at, second_factor_confirmed: true)
      end

      def verify(code, failures: 0, session: self.session)
        @sessions = FakeSessions.new
        @attempts = FakeAttempts.new(failures)
        @audit = FakeAudit.new
        VerifySecondFactor.new(users: FakeUsers.new, second_factors: @second_factors, sessions: @sessions, login_attempts: @attempts,
                               audit_log: @audit, policy: Policies::Identity::SecondFactorPolicy.new, digest_key: "key",
                               clock: Clock.new(NOW))
                          .call(session:, dto: Dtos::Identity::SecondFactorCodeInput.new(code:), ip: "1.2.3.4")
      end

      test "a right TOTP code verifies the session" do
        assert verify("123456").success?
        assert_equal 5, @sessions.verified
        assert_equal [ [ "0701020304", true, "second_factor" ] ], @attempts.records.map { it.values_at(:contact, :succeeded, :kind) }
        assert_empty @audit.entries
      end

      test "a replayed TOTP code is refused" do
        verify("123456")

        assert_equal :invalid, verify("123456").code
        assert_nil @sessions.verified
      end

      test "a backup code is accepted once and logged" do
        assert verify("abcDEF2345").success?
        assert_equal [ "backup_code.used" ], @audit.entries.map { it[:action] }

        assert_equal :invalid, verify("abcDEF2345").code
      end

      test "a wrong code is invalid and counts a failure" do
        [ "654321", "zzzDEF2345" ].each do |code|
          result = verify(code)

          assert_equal({ code: [ :invalid ] }, result.errors)
          assert_nil @sessions.verified
          assert_equal [ false ], @attempts.records.map { it[:succeeded] }
        end
      end

      test "the failure that reaches a tier is logged" do
        verify("654321", failures: 4)

        assert_equal [ "login.locked" ], @audit.entries.map { it[:action] }
        assert_equal({ kind: "second_factor", failures: 5 }, @audit.entries.first[:metadata])
      end

      test "after 5 failures the code is not checked" do
        result = verify("123456", failures: 5)

        assert_equal :locked, result.code
        assert_equal 14.minutes, result.errors[:retry_after]
        assert_empty @attempts.records
      end

      test "a malformed code is invalid and an already verified session is refused" do
        assert_equal :invalid, verify("12").code
        assert_equal({ base: [ :already_verified ] }, verify("123456", session: session(verified_at: NOW)).errors)
      end
    end
  end
end
