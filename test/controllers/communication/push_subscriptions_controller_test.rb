require "test_helper"

# notifications-push: the browser's subscription belongs to the current session of a student; a teacher is refused;
# a known address changes owner; a student removes only their own subscriptions.
module Communication
  class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
    ENDPOINT = "https://fcm.googleapis.com/fcm/send/abc123".freeze

    setup do
      @awa = create_student
    end

    def body(endpoint: ENDPOINT, **extra) = { endpoint:, keys: { p256dh: "BPkey", auth: "authkey" }, **extra }

    test "the subscription is attached to the current session, never to a user id sent by the client" do
      other = create_student
      sign_in_as @awa

      post push_subscriptions_path, params: body(user_id: other.id, session_id: 0), as: :json

      assert_response :created
      row = Orm::Communication::PushSubscription.find_by!(endpoint: ENDPOINT)
      assert_equal @awa.id, row.user_id
      assert_equal Orm::Session.where(user: @awa).order(:id).last.id, row.session_id
      assert_equal row.id, response.parsed_body["id"]
    end

    test "an address already known passes to the second student" do
      kofi = create_student
      sign_in_as @awa
      post push_subscriptions_path, params: body, as: :json
      delete session_path
      sign_in_as kofi

      post push_subscriptions_path, params: body, as: :json

      assert_response :created
      assert_equal [ kofi.id ], Orm::Communication::PushSubscription.where(endpoint: ENDPOINT).pluck(:user_id)
      assert_equal 1, Orm::Communication::PushSubscription.count
    end

    test "a teacher is refused and nothing is stored" do
      sign_in_as create_teacher

      post push_subscriptions_path, params: body, as: :json

      assert_response :forbidden
      assert_equal 0, Orm::Communication::PushSubscription.count
    end

    test "a visitor is sent to sign in" do
      post push_subscriptions_path, params: body, as: :json

      assert_equal 0, Orm::Communication::PushSubscription.count
      assert_not_equal 201, response.status
    end

    test "an unsafe address or missing keys are refused with 422" do
      sign_in_as @awa

      post push_subscriptions_path, params: body(endpoint: "http://127.0.0.1/x"), as: :json
      assert_response :unprocessable_entity
      assert_equal({ "endpoint" => [ "invalid" ] }, response.parsed_body["errors"])

      post push_subscriptions_path, params: { endpoint: ENDPOINT, keys: "oops" }, as: :json
      assert_response :unprocessable_entity

      post push_subscriptions_path, params: { endpoint: [ ENDPOINT ], keys: { p256dh: "k", auth: "a" } }, as: :json
      assert_response :unprocessable_entity
      assert_equal 0, Orm::Communication::PushSubscription.count
    end

    test "the student removes their own subscription and not another one" do
      mine = create_push_subscription(user: @awa)
      theirs = create_push_subscription(user: create_student)
      sign_in_as @awa

      delete push_subscription_path(theirs.id), as: :json
      assert_response :not_found
      assert Orm::Communication::PushSubscription.exists?(theirs.id)

      delete push_subscription_path(mine.id), as: :json
      assert_response :no_content
      assert_not Orm::Communication::PushSubscription.exists?(mine.id)
    end

    test "a teacher cannot remove a subscription" do
      row = create_push_subscription(user: @awa)
      sign_in_as create_teacher

      delete push_subscription_path(row.id), as: :json

      assert_response :forbidden
      assert Orm::Communication::PushSubscription.exists?(row.id)
    end
  end
end
