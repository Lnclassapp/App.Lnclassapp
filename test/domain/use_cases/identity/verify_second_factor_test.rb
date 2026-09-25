require "test_helper"

module UseCases
  module Identity
    class VerifySecondFactorTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def find(id:) = (Entities::Identity::User.new(id: 1, role: "team", team_role: "admin", contact: "0701020304") if id == 1)
      end

      class FakeSecondFactors
        include Ports::Identity::SecondFactorRepositoryPort

        def initialize(key) = @backup_digest = Entities::Identity::SecretDigest.hmac("abcDEF2345", key:)
        def verify_code(user_id:, code:, now:) = (42 if code == "123456")
        def consume_backup_code(user_id:, code_digest:, at:) = code_digest == @backup_digest
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

        attr_reader :actions

        def initialize = @actions = []
        def record(action:, **) = @actions << action
      end

      def verify(code, user_id: 1, failures: 0)
        @sessions = FakeSessions.new
        @attempts = FakeAttempts.new(failures)
        @audit = FakeAudit.new
        VerifySecondFactor.new(users: FakeUsers.new, second_factors: FakeSecondFactors.new("key"), sessions: @sessions,
                               login_attempts: @attempts, audit_log: @audit, digest_key: "key", clock: Clock.new(NOW))
                          .call(user_id:, session_id: 5, dto: Dtos::Identity::SecondFactorCodeInput.new(code:), ip: "1.2.3.4")
      end

      test "un code TOTP juste vérifie la session" do
        assert verify("123456").success?
        assert_equal 5, @sessions.verified
        assert_equal [ true ], @attempts.records.map { |record| record[:succeeded] }
        assert_equal "second_factor", @attempts.records.first[:kind]
        assert_empty @audit.actions
      end

      test "un code de secours juste est consommé et journalisé" do
        assert verify("abcDEF2345").success?
        assert_equal [ "backup_code.used" ], @audit.actions
      end

      test "un code faux ou rejoué est :invalid et compte un échec" do
        [ "654321", "zzzDEF2345" ].each do |code|
          result = verify(code)

          assert_equal :invalid, result.code
          assert_nil @sessions.verified
          assert_equal [ false ], @attempts.records.map { |record| record[:succeeded] }
        end
      end

      test "après 5 échecs, :locked sans vérifier le code" do
        result = verify("123456", failures: 5)

        assert_equal :locked, result.code
        assert_empty @attempts.records
      end

      test "saisie mal formée : :invalid ; compte absent : :not_found" do
        assert_equal :invalid, verify("12").code
        assert_equal :not_found, verify("123456", user_id: 2).code
      end
    end
  end
end
