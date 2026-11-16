require "test_helper"

module UseCases
  module Communication
    # notifications-push: « Couper », « Réactiver » and « Plus tard » on the student's own preference; the ports are faked.
    class PushPreferenceUseCasesTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 16, 12)

      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(users) = @users = users
        def find(id:) = @users[id]
      end

      class FakePreferences
        include Ports::Communication::PushPreferenceRepositoryPort

        attr_reader :calls

        def initialize = @calls = []

        def turn_off(user_id:, at:) = @calls << [ :turn_off, user_id, at ]
        def turn_on(user_id:) = @calls << [ :turn_on, user_id ]
        def postpone_invitation(user_id:, until_time:) = @calls << [ :postpone, user_id, until_time ]
      end

      class FakeSubscriptions
        include Ports::Communication::PushSubscriptionRepositoryPort

        attr_reader :deleted_sessions

        def delete_for_sessions(session_ids:) = (@deleted_sessions = session_ids).size
      end

      class FakeClock
        def now = NOW
      end

      setup do
        @student = Entities::Identity::User.new(id: 5, role: "student")
        @actor = Entities::Identity::Actor.new(user_id: 5, role: :student)
        @teacher = Entities::Identity::Actor.new(user_id: 6, role: :teacher)
        @preferences = FakePreferences.new
        @subscriptions = FakeSubscriptions.new
        @deps = { users: FakeUsers.new(5 => @student, 6 => Entities::Identity::User.new(id: 6, role: "teacher")),
                  preferences: @preferences, policy: Policies::Communication::PushSubscriptionPolicy.new }
      end

      test "turning off marks the student and removes the subscription of the current session only" do
        result = TurnOffPush.new(**@deps, subscriptions: @subscriptions, clock: FakeClock.new).call(actor: @actor, session_id: 9)

        assert_predicate result, :success?
        assert_equal [ [ :turn_off, 5, NOW ] ], @preferences.calls
        assert_equal [ 9 ], @subscriptions.deleted_sessions
      end

      test "turning off is refused to a teacher and writes nothing" do
        result = TurnOffPush.new(**@deps, subscriptions: @subscriptions, clock: FakeClock.new).call(actor: @teacher, session_id: 9)

        assert_equal :forbidden, result.code
        assert_empty @preferences.calls
        assert_nil @subscriptions.deleted_sessions
      end

      test "turning on clears the switch" do
        assert_predicate TurnOnPush.new(**@deps).call(actor: @actor), :success?
        assert_equal [ [ :turn_on, 5 ] ], @preferences.calls
      end

      test "turning on is refused to a teacher" do
        assert_equal :forbidden, TurnOnPush.new(**@deps).call(actor: @teacher).code
        assert_empty @preferences.calls
      end

      test "postponing hides the invitation for seven days" do
        assert_predicate PostponePushInvitation.new(**@deps, clock: FakeClock.new).call(actor: @actor), :success?
        assert_equal [ [ :postpone, 5, NOW + 7.days ] ], @preferences.calls
      end

      test "postponing is refused to a teacher" do
        assert_equal :forbidden, PostponePushInvitation.new(**@deps, clock: FakeClock.new).call(actor: @teacher).code
        assert_empty @preferences.calls
      end
    end
  end
end
