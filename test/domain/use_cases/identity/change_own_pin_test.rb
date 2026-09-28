require "test_helper"

module UseCases
  module Identity
    # PR-06, PR-07, ADR-0055: the PIN changes under the current PIN, typed twice; a typing error costs no PIN attempt;
    # the same PIN is refused; a new session replaces every other one, and « pin.changed » is audited without any data.
    class ChangeOwnPinTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 27, 12)
      KEY = "key".freeze
      Clock = Data.define(:now)

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        attr_reader :checked, :updates

        def initialize(user) = (@user, @checked, @updates = user, 0, [])

        def authenticate(contact:, pin:)
          @checked += 1
          @user if contact == @user.contact && pin == "2468"
        end

        def update_pin(user_id:, pin:) = @updates << [ user_id, pin ]
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :created, :verified, :kept

        def create(**attributes)
          @created = attributes
          42
        end

        def mark_second_factor_verified(id:, at:) = @verified = { id:, at: }
        def destroy_all_except(user_id:, keep_id:) = @kept = { user_id:, keep_id: }
      end

      class FakeAttempts
        include Ports::Identity::LoginAttemptRepositoryPort

        attr_reader :records

        def initialize(count:, last_failed_at:) = (@failures, @records = Failures.new(count:, last_failed_at:), [])
        def consecutive_failures(contact:, kind:) = @failures
        def record(**attributes) = @records << attributes
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :entries

        def initialize = @entries = []
        def record(**entry) = @entries << entry
      end

      setup do
        @user = Entities::Identity::User.new(id: 3, contact: "0501020304", role: "teacher")
        @actor = Entities::Identity::Actor.new(user_id: 3, role: :teacher)
        @users = FakeUsers.new(@user)
        @sessions = FakeSessions.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
      end

      def session(verified_at: nil)
        Entities::Identity::SessionState.new(id: 7, user_id: 3, role: "teacher", created_at: NOW - 1.day, last_seen_at: NOW,
                                             second_factor_verified_at: verified_at, second_factor_confirmed: false)
      end

      def input(current_pin: "2468", pin: "1357", pin_confirmation: pin)
        Dtos::Identity::PinChangeInput.new(current_pin:, pin:, pin_confirmation:, ip: "1.2.3.4", user_agent: "Firefox")
      end

      def change(dto = input, actor: @actor, current: session, failures: 0, last_failed_at: nil)
        @attempts = FakeAttempts.new(count: failures, last_failed_at:)
        ChangeOwnPin.new(users: @users, sessions: @sessions, login_attempts: @attempts, audit_log: @audit, transaction: @transaction,
                         policy: Policies::Identity::UpdateSelfPolicy.new, digest_key: KEY, clock: Clock.new(NOW))
                    .call(actor:, user: @user, session: current, dto:)
      end

      def assert_nothing_written
        assert_empty @users.updates
        assert_nil @sessions.created
        assert_nil @sessions.kept
        assert_not_includes @audit.entries.map { it[:action] }, "pin.changed"
      end

      test "the new PIN is written, a new session replaces every other one, and the change is audited without any data" do
        result = change

        assert result.success?
        token = result.value.token
        assert_equal [ [ 3, "1357" ] ], @users.updates
        assert_equal({ user_id: 3, token_digest: Entities::Identity::SecretDigest.hmac(token, key: KEY), ip: "1.2.3.4",
                       user_agent: "Firefox", at: NOW }, @sessions.created)
        assert_nil @sessions.verified
        assert_equal({ user_id: 3, keep_id: 42 }, @sessions.kept)
        assert_equal [ { action: "pin.changed", actor_id: 3, subject_type: "User", subject_id: 3, ip: "1.2.3.4", at: NOW } ],
                     @audit.entries
        assert_equal [ true ], @attempts.records.map { it[:succeeded] }
        assert_equal 1, @transaction.calls
      end

      test "a verified second factor stays verified on the new session" do
        change(current: session(verified_at: NOW - 1.minute))

        assert_equal({ id: 42, at: NOW }, @sessions.verified)
      end

      test "another account is forbidden, before the PIN is checked" do
        result = change(actor: Entities::Identity::Actor.new(user_id: 4, role: :teacher))

        assert_equal :forbidden, result.code
        assert_equal 0, @users.checked
        assert_nothing_written
      end

      test "a wrong current PIN is refused and counts as a failed sign-in, and nothing is written" do
        result = change(input(current_pin: "9753"))

        assert_equal [ :invalid, { current_pin: [ :incorrect ] } ], [ result.code, result.errors ]
        assert_equal [ false ], @attempts.records.map { it[:succeeded] }
        assert_nothing_written
      end

      test "the wrong PIN that reaches the threshold locks the account" do
        result = change(input(current_pin: "9753"), failures: 4, last_failed_at: NOW - 1.minute)

        assert_equal [ :locked, { retry_after: 15.minutes } ], [ result.code, result.errors ]
        assert_nothing_written
      end

      test "a confirmation that differs is refused under its field, and costs no PIN attempt" do
        result = change(input(pin_confirmation: "1358"))

        assert_equal [ :invalid, { pin_confirmation: [ "Les deux PIN ne sont pas identiques." ] } ], [ result.code, result.errors ]
        assert_equal 0, @users.checked
        assert_empty @attempts.records
        assert_nothing_written
      end

      test "a PIN out of format, and a blank field, are refused without checking the PIN" do
        {
          input(pin: "12345") => { pin: [ :invalid ] },
          input(pin: "12a4") => { pin: [ :invalid ] },
          input(current_pin: "") => { current_pin: [ :blank ] },
          input(current_pin: "246") => { current_pin: [ :invalid ] },
          input(pin: "", pin_confirmation: "") => { pin: [ :blank ] }
        }.each do |dto, details|
          assert_equal :invalid, change(dto).code
          assert_equal details, dto.errors.details.transform_values { |errors| errors.map { it[:error] } }
        end
        assert_equal 0, @users.checked
        assert_nothing_written
      end

      test "the current PIN as the new one is refused once the current PIN is checked, and nothing is written" do
        result = change(input(pin: "2468"))

        assert_equal [ :invalid, { pin: [ :unchanged ] } ], [ result.code, result.errors ]
        assert_equal 1, @users.checked
        assert_nothing_written
      end
    end
  end
end
