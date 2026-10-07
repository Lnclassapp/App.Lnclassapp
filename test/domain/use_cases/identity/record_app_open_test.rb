require "test_helper"

module UseCases
  module Identity
    # ADR-0082 §4.3, CA-10: an opening from the installed app's icon dates the actor's own account at the server's
    # time. A storage failure never raises: it is reported as handled, and the caller carries on.
    class RecordAppOpenTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 7, 8, 15)
      Clock = Data.define(:now)
      # The storage failure the delivery layer declares recoverable (ActiveRecord::ActiveRecordError in production).
      Unavailable = Class.new(StandardError)

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        attr_reader :openings

        def initialize(failure: nil)
          @failure = failure
          @openings = []
        end

        def mark_app_opened(user_id:, at:)
          raise @failure if @failure

          @openings << [ user_id, at ]
          true
        end
      end

      class FakeReporter
        attr_reader :reports

        def initialize = @reports = []
        def report(error, **options) = @reports << [ error, options ]
      end

      setup do
        @users = FakeUsers.new
        @reporter = FakeReporter.new
      end

      def record(actor: Entities::Identity::Actor.new(user_id: 7, role: :student), users: @users)
        RecordAppOpen.new(users:, policy: Policies::Identity::RecordAppOpenPolicy.new, clock: Clock.new(NOW),
                          reporter: @reporter, recoverable: Unavailable).call(actor:)
      end

      test "a direction, a team member or no actor is refused: nothing is dated, and a refusal is not reported" do
        [ Entities::Identity::Actor.new(user_id: 8, role: :school_admin, school_id: 3),
          Entities::Identity::Actor.new(user_id: 9, role: :team, team_role: "admin"), nil ].each do |actor|
          assert_equal :forbidden, record(actor:).code, actor&.role.inspect
        end

        assert_empty @users.openings
        assert_empty @reporter.reports
      end

      test "dates the actor's own account at the clock's time" do
        result = record

        assert result.success?
        assert result.value
        assert_equal [ [ 7, NOW ] ], @users.openings
        assert_empty @reporter.reports
      end

      test "a teacher's opening is dated the same way, on their own account only" do
        assert record(actor: Entities::Identity::Actor.new(user_id: 12, role: :teacher, school_id: 3)).success?

        assert_equal [ [ 12, NOW ] ], @users.openings
      end

      test "a storage failure never raises: nothing is dated, the error is reported as handled, with the account" do
        error = Unavailable.new("base indisponible")

        result = record(users: FakeUsers.new(failure: error))

        assert result.success?
        assert_not result.value
        assert_equal [ [ error, { handled: true, context: { user_id: 7 } } ] ], @reporter.reports
      end

      test "any other error is a bug, not a storage failure: it is neither swallowed nor reported" do
        error = NoMethodError.new("undefined method for nil")

        assert_raises(NoMethodError) { record(users: FakeUsers.new(failure: error)) }
        assert_empty @reporter.reports
      end
    end
  end
end
