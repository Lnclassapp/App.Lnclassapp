require "test_helper"

module UseCases
  module Communication
    # notifications-push: a subscription belongs to the current session of a student, never to an id sent by the client;
    # a teacher is refused; an address already known changes owner (the repository does it); the address is validated.
    class RegisterPushSubscriptionTest < ActiveSupport::TestCase
      class FakeUsers
        include Ports::Identity::UserRepositoryPort

        def initialize(users) = @users = users
        def find(id:) = @users[id]
      end

      class FakeSubscriptions
        include Ports::Communication::PushSubscriptionRepositoryPort

        attr_reader :registered, :deleted

        def initialize(existing = []) = (@existing, @registered, @deleted = existing, [], [])

        def register(user_id:, session_id:, endpoint:, p256dh:, auth:)
          @registered << { user_id:, session_id:, endpoint:, p256dh:, auth: }
          Entities::Communication::PushSubscription.new(id: 31, user_id:, session_id:, endpoint:, p256dh:, auth:)
        end

        def for_user(user_id:) = @existing.select { it.user_id == user_id }
        def delete(id:) = (@deleted << id).size
      end

      ENDPOINT = "https://fcm.googleapis.com/fcm/send/abc".freeze

      setup do
        @actor = Entities::Identity::Actor.new(user_id: 5, role: :student)
        @users = FakeUsers.new(5 => Entities::Identity::User.new(id: 5, role: "student"),
                               6 => Entities::Identity::User.new(id: 6, role: "teacher"))
        @subscriptions = FakeSubscriptions.new
        @policy = Policies::Communication::PushSubscriptionPolicy.new
      end

      def register(actor: @actor, endpoint: ENDPOINT, p256dh: "BPkey", auth: "authkey")
        RegisterPushSubscription.new(users: @users, subscriptions: @subscriptions, policy: @policy)
                                .call(actor:, session_id: 9, endpoint:, p256dh:, auth:)
      end

      test "the subscription is attached to the actor and the current session" do
        result = register

        assert_predicate result, :success?
        assert_equal [ { user_id: 5, session_id: 9, endpoint: ENDPOINT, p256dh: "BPkey", auth: "authkey" } ], @subscriptions.registered
        assert_equal 31, result.value.id
      end

      test "a teacher is refused and nothing is stored" do
        result = register(actor: Entities::Identity::Actor.new(user_id: 6, role: :teacher))

        assert_equal :forbidden, result.code
        assert_empty @subscriptions.registered
      end

      test "an address that is not a public https address is invalid" do
        [ nil, "", "http://fcm.googleapis.com/x", "https://localhost/x", "https://127.0.0.1/x", "https://[::1]/x",
          "https://user:pw@fcm.googleapis.com/x", "not a url", "https://#{'a' * 2050}.example/x", "ftp://x.example/x" ].each do |endpoint|
          result = register(endpoint:)

          assert_equal :invalid, result.code, endpoint.inspect
          assert_equal({ endpoint: [ :invalid ] }, result.errors)
        end
        assert_empty @subscriptions.registered
      end

      test "missing or oversized keys are invalid" do
        assert_equal({ p256dh: [ :invalid ] }, register(p256dh: "").errors)
        assert_equal({ auth: [ :invalid ] }, register(auth: nil).errors)
        assert_equal({ auth: [ :invalid ] }, register(auth: "a" * 300).errors)
        assert_empty @subscriptions.registered
      end
    end

    # The student removes one of their own subscriptions; another student's id is not found.
    class UnregisterPushSubscriptionTest < ActiveSupport::TestCase
      setup do
        @mine = Entities::Communication::PushSubscription.new(id: 31, user_id: 5, endpoint: "https://x.example/a", p256dh: "k", auth: "a")
        @theirs = Entities::Communication::PushSubscription.new(id: 32, user_id: 6, endpoint: "https://x.example/b", p256dh: "k", auth: "a")
        @subscriptions = RegisterPushSubscriptionTest::FakeSubscriptions.new([ @mine, @theirs ])
        users = RegisterPushSubscriptionTest::FakeUsers.new(5 => Entities::Identity::User.new(id: 5, role: "student"),
                                                           6 => Entities::Identity::User.new(id: 6, role: "teacher"))
        @use_case = UnregisterPushSubscription.new(users:, subscriptions: @subscriptions, policy: Policies::Communication::PushSubscriptionPolicy.new)
      end

      test "the student removes their own subscription" do
        assert_predicate @use_case.call(actor: Entities::Identity::Actor.new(user_id: 5, role: :student), id: 31), :success?
        assert_equal [ 31 ], @subscriptions.deleted
      end

      test "another account's subscription is not found and stays" do
        assert_equal :not_found, @use_case.call(actor: Entities::Identity::Actor.new(user_id: 5, role: :student), id: 32).code
        assert_empty @subscriptions.deleted
      end

      test "a teacher is refused" do
        assert_equal :forbidden, @use_case.call(actor: Entities::Identity::Actor.new(user_id: 6, role: :teacher), id: 32).code
        assert_empty @subscriptions.deleted
      end
    end
  end
end
