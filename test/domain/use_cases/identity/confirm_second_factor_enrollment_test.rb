require "test_helper"

module UseCases
  module Identity
    class ConfirmSecondFactorEnrollmentTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      class FakeSecondFactors
        include Ports::Identity::SecondFactorRepositoryPort

        attr_reader :confirmed

        def verify_code(user_id:, code:, now:) = (42 if code == "123456")
        def confirm(user_id:, backup_code_digests:, at:) = @confirmed = [ user_id, backup_code_digests, at ]
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :verified

        def mark_second_factor_verified(id:, at:) = @verified = [ id, at ]
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

      def session(confirmed: false)
        Entities::Identity::SessionState.new(id: 5, user_id: 9, role: "team", created_at: nil, last_seen_at: nil,
                                             second_factor_verified_at: nil, second_factor_confirmed: confirmed)
      end

      def confirm(code, session: self.session)
        @second_factors = FakeSecondFactors.new
        @sessions = FakeSessions.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        ConfirmSecondFactorEnrollment.new(second_factors: @second_factors, sessions: @sessions, audit_log: @audit,
                                          transaction: @transaction, policy: Policies::Identity::SecondFactorPolicy.new,
                                          digest_key: "key", clock: Clock.new(NOW))
                                     .call(session:, dto: Dtos::Identity::SecondFactorCodeInput.new(code:))
      end

      test "a right code confirms the factor, verifies the session and returns ten clear backup codes once" do
        result = confirm("123 456")

        codes = result.value
        assert_equal 10, codes.size
        assert_equal [ 9, codes.map { Entities::Identity::SecretDigest.hmac(it, key: "key") }, NOW ], @second_factors.confirmed
        assert_equal [ 5, NOW ], @sessions.verified
        assert_equal [ "totp.enrolled" ], @audit.actions
        assert @transaction.opened
      end

      test "a wrong, malformed or backup code is invalid" do
        assert_equal({ code: [ :invalid ] }, confirm("654321").errors)
        assert_equal({ code: [ :invalid ] }, confirm("abcDEF2345").errors)
        assert confirm("").errors.key?(:code)
        assert_nil @second_factors.confirmed
      end

      test "an already confirmed factor is refused" do
        assert_equal :forbidden, confirm("123456", session: session(confirmed: true)).code
      end
    end
  end
end
