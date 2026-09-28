require "test_helper"

module UseCases
  module Identity
    # ADR-0055, PR-04, PR-05, PR-07: the number changes under the current PIN, typed twice; the other sessions close,
    # the current one is renewed under a new token, and the audit log keeps both numbers masked.
    class ChangeOwnContactTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 27, 12)
      KEY = "key".freeze
      Clock = Data.define(:now)

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        attr_reader :checked, :updated

        def initialize(user, taken: [])
          @user = user
          @taken = taken
          @checked = 0
        end

        def authenticate(contact:, pin:)
          @checked += 1
          @user if contact == @user.contact && pin == "2468"
        end

        def update_contact(user_id:, contact:)
          return Shared::Result.failure(:conflict, errors: { contact: [ :taken ] }) if @taken.include?(contact)

          @updated = { user_id:, contact: }
          Shared::Result.success
        end
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
        @user = Entities::Identity::User.new(id: 3, contact: "0101020304", role: "student")
        @session = Entities::Identity::SessionState.new(id: 7, user_id: 3, role: "student", created_at: NOW - 1.day,
                                                        last_seen_at: NOW, second_factor_verified_at: nil, second_factor_confirmed: false)
        @actor = Entities::Identity::Actor.new(user_id: 3, role: :student)
        @users = FakeUsers.new(@user, taken: [ "0500000001" ])
        @sessions = FakeSessions.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
      end

      def input(**overrides)
        Dtos::Identity::ContactChangeInput.new(current_pin: "2468", contact: "07 11 22 33 44", contact_confirmation: "0711223344",
                                               ip: "1.2.3.4", user_agent: "Firefox", **overrides)
      end

      def change(dto = input, actor: @actor, failures: 0, last_failed_at: nil)
        @attempts = FakeAttempts.new(count: failures, last_failed_at:)
        ChangeOwnContact.new(users: @users, sessions: @sessions, login_attempts: @attempts, audit_log: @audit,
                             transaction: @transaction, policy: Policies::Identity::UpdateSelfPolicy.new, digest_key: KEY,
                             clock: Clock.new(NOW))
                        .call(actor:, user: @user, session: @session, dto:)
      end

      def assert_nothing_written
        assert_nil @users.updated
        assert_nil @sessions.created
        assert_nil @sessions.kept
        assert_empty @audit.entries.reject { it[:action] == "login.locked" }
      end

      test "the number changes, a new session replaces every other one, and the audit keeps the numbers masked" do
        result = change

        assert result.success?
        assert_equal({ user_id: 3, contact: "0711223344" }, @users.updated)
        token = result.value.token
        assert_equal({ user_id: 3, token_digest: Entities::Identity::SecretDigest.hmac(token, key: KEY), ip: "1.2.3.4",
                       user_agent: "Firefox", at: NOW }, @sessions.created)
        assert_equal({ user_id: 3, keep_id: 42 }, @sessions.kept)
        assert_nil @sessions.verified
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "contact.changed", actor_id: 3, subject_type: "User", subject_id: 3,
                         metadata: { from: "********04", to: "********44" }, ip: "1.2.3.4", at: NOW } ], @audit.entries
      end

      test "the success counts as a sign-in success, on the counter of the sign-in" do
        change

        assert_equal [ [ true, "0101020304" ] ], @attempts.records.map { it.values_at(:succeeded, :contact) }
      end

      test "no PIN ever enters the audit log" do
        change

        assert_no_match(/2468/, @audit.entries.inspect)
      end

      test "a team session whose second factor was verified keeps it verified once renewed" do
        @session = @session.with(role: "team", second_factor_verified_at: NOW - 1.hour, second_factor_confirmed: true)

        assert change.success?
        assert_equal({ id: 42, at: NOW }, @sessions.verified)
      end

      test "another account is forbidden, before any check" do
        result = change(actor: Entities::Identity::Actor.new(user_id: 4, role: :student))

        assert_equal :forbidden, result.code
        assert_equal 0, @users.checked
        assert_nothing_written
      end

      test "an invalid form is refused before the PIN is checked, and no failure is counted" do
        result = change(input(contact_confirmation: "0711223345"))

        assert_equal :invalid, result.code
        assert_equal [ :contact_confirmation ], result.errors.keys
        assert_equal 0, @users.checked
        assert_empty @attempts.records
        assert_nothing_written
      end

      test "the current number is refused, without checking the PIN" do
        result = change(input(contact: "01 01 02 03 04", contact_confirmation: "0101020304"))

        assert_equal [ :invalid, { contact: [ :unchanged ] } ], [ result.code, result.errors ]
        assert_equal 0, @users.checked
        assert_nothing_written
      end

      test "a wrong PIN is refused and counts as a failed sign-in" do
        result = change(input(current_pin: "1357"))

        assert_equal [ :invalid, { current_pin: [ :incorrect ] } ], [ result.code, result.errors ]
        assert_equal [ false ], @attempts.records.map { it[:succeeded] }
        assert_nothing_written
      end

      test "the wrong PIN that reaches the threshold locks the account" do
        result = change(input(current_pin: "1357"), failures: 4, last_failed_at: NOW - 1.hour)

        assert_equal [ :locked, { retry_after: 15.minutes } ], [ result.code, result.errors ]
        assert_equal [ "login.locked" ], @audit.entries.map { it[:action] }
        assert_nothing_written
      end

      test "a number taken by another account is a conflict, and nothing is written" do
        result = change(input(contact: "0500000001", contact_confirmation: "0500000001"))

        assert_equal [ :conflict, { contact: [ :taken ] } ], [ result.code, result.errors ]
        assert_nothing_written
      end
    end
  end
end
