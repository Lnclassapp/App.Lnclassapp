require "test_helper"

module UseCases
  module Identity
    class AuthenticateTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(user) = @user = user
        def authenticate(contact:, pin:)
          @user if contact == @user.contact && pin == "2468"
        end

        def find_by_contact(contact:)
          @user if contact == @user.contact
        end
      end

      class FakeAttempts
        include Ports::Identity::LoginAttemptRepositoryPort

        attr_reader :records

        def initialize(count: 0, last_failed_at: nil)
          @failures = Failures.new(count:, last_failed_at:)
          @records = []
        end

        def consecutive_failures(contact:, kind:) = @failures
        def record(**attributes) = @records << attributes
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :created

        def create(**attributes)
          @created = attributes
          7
        end
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :entries

        def initialize = @entries = []
        def record(**entry) = @entries << entry
      end

      setup do
        @user = Entities::Identity::User.new(id: 1, contact: "0701020304", role: "student")
        @sessions = FakeSessions.new
        @audit = FakeAudit.new
      end

      def authenticate(pin: "2468", contact: "07 01 02 03 04", attempts: FakeAttempts.new, client: nil)
        @attempts = attempts
        dto = Dtos::Identity::CredentialsInput.new(contact:, pin:, ip: "1.2.3.4", user_agent: "UA", **{ client: }.compact)
        Authenticate.new(users: FakeUsers.new(@user), login_attempts: attempts, sessions: @sessions, audit_log: @audit,
                         digest_key: "key", clock: Clock.new(NOW)).call(dto:)
      end

      test "opens a session and returns the user with the clear token" do
        result = authenticate

        assert result.success?
        assert_equal @user, result.value.user
        assert_equal Entities::Identity::SecretDigest.hmac(result.value.token, key: "key"), @sessions.created[:token_digest]
        assert_equal({ user_id: 1, ip: "1.2.3.4", user_agent: "UA", at: NOW }, @sessions.created.except(:token_digest))
        assert_equal [ { contact: "0701020304", user_id: 1, ip: "1.2.3.4", succeeded: true, kind: "pin", at: NOW } ], @attempts.records
      end

      test "the +225 and 00225 prefixes reach the same account" do
        assert authenticate(contact: "+225 07 01 02 03 04").success?
        assert authenticate(contact: "002250701020304").success?
      end

      test "a malformed input is invalid and writes nothing" do
        result = authenticate(pin: "12")

        assert_equal :invalid, result.code
        assert result.errors.key?(:pin)
        assert_empty @attempts.records
      end

      test "a wrong PIN and an unknown number get the same message" do
        wrong_pin = authenticate(pin: "1357")
        unknown = authenticate(contact: "0501020304")

        assert_equal :invalid, wrong_pin.code
        assert_equal wrong_pin.errors, unknown.errors
        assert_equal({ base: [ :invalid_credentials ] }, unknown.errors)
        assert_equal [ false ], @attempts.records.map { it[:succeeded] }
        assert_nil @sessions.created
        assert_empty @audit.entries
      end

      test "the fifth failure writes the lockout in the audit log" do
        authenticate(pin: "1357", attempts: FakeAttempts.new(count: 4, last_failed_at: NOW - 1.hour))

        assert_equal [ "login.locked" ], @audit.entries.map { it[:action] }
        assert_equal [ 1, { kind: "pin", failures: 5 } ], @audit.entries.first.values_at(:subject_id, :metadata)
      end

      test "the lockout of an unknown number is logged without a subject" do
        authenticate(contact: "0501020304", attempts: FakeAttempts.new(count: 9, last_failed_at: NOW - 2.hours))

        assert_nil @audit.entries.first[:subject_id]
      end

      test "after 5 failures the sixth attempt, even right, is locked without checking the PIN" do
        result = authenticate(attempts: FakeAttempts.new(count: 5, last_failed_at: NOW - 1.minute))

        assert_equal :locked, result.code
        assert_equal 14.minutes, result.errors[:retry_after]
        assert_empty @attempts.records
      end

      test "tiers 10 and 20" do
        assert_equal 1.hour, authenticate(attempts: FakeAttempts.new(count: 10, last_failed_at: NOW)).errors[:retry_after]
        assert_equal :until_recovery, authenticate(attempts: FakeAttempts.new(count: 20, last_failed_at: NOW - 1.year)).errors[:retry_after]
      end

      test "an elapsed lockout lets the account in again" do
        assert authenticate(attempts: FakeAttempts.new(count: 5, last_failed_at: NOW - 16.minutes)).success?
      end

      # ADR-0084 §4.5, ADR-0086 §4.5, CA-3, CA-T3: in an Android shell, the role is checked only once the PIN is right; the
      # refusal names the app to propose.
      ROLE_ATTRIBUTES = { "student" => { role: "student" }, "teacher" => { role: "teacher" },
                          "school_admin" => { role: "school_admin" }, "team" => { role: "team", team_role: "admin" } }.freeze

      {
        [ "android_student", "teacher" ] => :android_teacher,
        [ "android_student", "school_admin" ] => :web,
        [ "android_student", "team" ] => :web,
        [ "android_teacher", "student" ] => :android_student,
        [ "android_teacher", "school_admin" ] => :web,
        [ "android_teacher", "team" ] => :web
      }.each do |(client, role), app|
        test "CA-3, CA-T3: in the #{client} shell, a #{role} with the right PIN is sent to #{app}, without a session" do
          @user = Entities::Identity::User.new(id: 1, contact: "0701020304", **ROLE_ATTRIBUTES.fetch(role))
          result = authenticate(client:)

          assert_equal :conflict, result.code
          assert_equal({ base: [ :wrong_app ], app: [ app ] }, result.errors)
          assert_equal [ true ], @attempts.records.map { it[:succeeded] }
          assert_nil @sessions.created
        end
      end

      test "CA-3, CA-T3: in either shell, a wrong PIN gets exactly the same failure, whatever the role" do
        failures = %w[android_student android_teacher web].product(ROLE_ATTRIBUTES.values).map do |client, attributes|
          @user = Entities::Identity::User.new(id: 1, contact: "0701020304", **attributes)
          result = authenticate(pin: "1357", client:)

          assert_equal [ false ], @attempts.records.map { it[:succeeded] }
          result
        end

        assert_equal [ Shared::Result.failure(:invalid, errors: Authenticate::INVALID) ], failures.uniq
        assert_nil @sessions.created
      end

      test "CA-4: in the students' app, a student with the right PIN gets a session" do
        result = authenticate(client: "android_student")

        assert result.success?
        assert_equal @user, result.value.user
        assert_equal 1, @sessions.created[:user_id]
      end

      test "CA-T4: in the teachers' app, a teacher with the right PIN gets a session" do
        @user = Entities::Identity::User.new(id: 1, contact: "0701020304", role: "teacher")
        result = authenticate(client: "android_teacher")

        assert result.success?
        assert_equal @user, result.value.user
        assert_equal 1, @sessions.created[:user_id]
      end

      test "on the website, by default or by name, every role signs in as before" do
        ROLE_ATTRIBUTES.each_value do |attributes|
          @user = Entities::Identity::User.new(id: 1, contact: "0701020304", **attributes)

          assert authenticate.success?, attributes
          assert authenticate(client: "web").success?, attributes
        end
      end

      test "an unknown client is invalid and writes nothing" do
        result = authenticate(client: "ios")

        assert_equal :invalid, result.code
        assert result.errors.key?(:client)
        assert_empty @attempts.records
      end
    end
  end
end
