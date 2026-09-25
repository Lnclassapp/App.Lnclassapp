require "test_helper"

module UseCases
  module Identity
    class ConfirmSecondFactorEnrollmentTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      State = Ports::Identity::SecondFactorRepositoryPort::State

      class FakeSecondFactors
        include Ports::Identity::SecondFactorRepositoryPort

        attr_reader :confirmed_digests

        def initialize(state) = @state = state
        def state_for(user_id:) = @state
        def verify_code(user_id:, code:, now:) = (42 if code == "123456")
        def confirm(user_id:, backup_code_digests:, at:) = @confirmed_digests = backup_code_digests
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :verified

        def mark_second_factor_verified(id:, at:) = @verified = id
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

      def confirm(code: "123456", state: State.new(confirmed: false, backup_codes_left: 0))
        @second_factors = FakeSecondFactors.new(state)
        @sessions = FakeSessions.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        ConfirmSecondFactorEnrollment.new(second_factors: @second_factors, sessions: @sessions, audit_log: @audit,
                                          transaction: @transaction, digest_key: "key", clock: Clock.new(NOW))
                                     .call(user_id: 1, session_id: 5, dto: Dtos::Identity::SecondFactorCodeInput.new(code:))
      end

      test "confirme, vérifie la session et renvoie 10 codes en clair dont seules les empreintes sont stockées" do
        result = confirm

        assert_equal 10, result.value.size
        assert_equal result.value.map { |code| Entities::Identity::SecretDigest.hmac(code, key: "key") }, @second_factors.confirmed_digests
        assert_equal 5, @sessions.verified
        assert_equal [ "totp.enrolled" ], @audit.actions
        assert @transaction.opened
      end

      test "un code faux, un code de secours ou une saisie vide est :invalid" do
        assert_equal :invalid, confirm(code: "654321").code
        assert_equal :invalid, confirm(code: "abcDEF2345").code
        assert_equal :invalid, confirm(code: "").code
        assert_nil @second_factors.confirmed_digests
      end

      test "sans activation en cours ou déjà confirmé : :conflict" do
        assert_equal :conflict, confirm(state: nil).code
        assert_equal :conflict, confirm(state: State.new(confirmed: true, backup_codes_left: 10)).code
        assert_nil @sessions.verified
      end
    end
  end
end
