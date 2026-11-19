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

        def delete_oldest_beyond(user_id:, limit:)
          @trimmed = { user_id:, limit: }
          0
        end

        attr_reader :trimmed
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

      test "an address outside the closed list of push services is invalid" do
        [ nil, "", "http://fcm.googleapis.com/x", "https://localhost/x", "https://127.0.0.1/x", "https://[::1]/x",
          "https://user:pw@fcm.googleapis.com/x", "not a url", "https://fcm.googleapis.com/#{'a' * 2050}", "ftp://fcm.googleapis.com/x",
          "https://metadata.google.internal/x", "https://evil.example/x", "https://fcm.googleapis.com:8443/x",
          "https://fcm.googleapis.com.evil.example/x", "https://push.apple.com/x", "https://evilpush.apple.com/x",
          "https://x.notify.windows.com.evil.example/x" ].each do |endpoint|
          result = register(endpoint:)

          assert_equal :invalid, result.code, endpoint.inspect
          assert_equal({ endpoint: [ :invalid ] }, result.errors)
        end
        assert_empty @subscriptions.registered
      end

      test "the addresses of the browsers' push services are accepted" do
        %w[https://fcm.googleapis.com/fcm/send/abc https://android.googleapis.com/gcm/send/abc https://updates.push.services.mozilla.com/wpush/v2/abc
           https://web.push.apple.com/abc https://wns2-par02p.notify.windows.com/w/?token=abc https://FCM.googleapis.com:443/x].each do |endpoint|
          assert_predicate register(endpoint:), :success?, endpoint
        end
      end

      test "registering keeps the five most recent subscriptions of the student" do
        register

        assert_equal({ user_id: 5, limit: 5 }, @subscriptions.trimmed)
      end

      test "an invalid registration trims nothing" do
        register(endpoint: "https://evil.example/x")

        assert_nil @subscriptions.trimmed
      end

      test "a missing actor is refused" do
        assert_equal :forbidden, register(actor: nil).code
      end

      test "missing or oversized keys are invalid" do
        assert_equal({ p256dh: [ :invalid ] }, register(p256dh: "").errors)
        assert_equal({ auth: [ :invalid ] }, register(auth: nil).errors)
        assert_equal({ auth: [ :invalid ] }, register(auth: "a" * 300).errors)
        assert_empty @subscriptions.registered
      end
    end
  end
end
