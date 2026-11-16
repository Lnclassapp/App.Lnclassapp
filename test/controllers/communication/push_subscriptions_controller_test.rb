require "test_helper"

# notifications-push: the browser's subscription belongs to the current session of a student; a teacher is refused;
# a known address changes owner; the school management and the team are refused; a limit of requests per minute.
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
      create_push_subscription(user: @awa, endpoint: ENDPOINT)
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

    test "the school management is refused and nothing is stored" do
      sign_in_as create_school_admin

      post push_subscriptions_path, params: body, as: :json

      assert_response :forbidden
      assert_equal 0, Orm::Communication::PushSubscription.count
    end

    test "a team member is refused and nothing is stored" do
      sign_in_as create_team_member

      post push_subscriptions_path, params: body, as: :json

      assert_response :forbidden
      assert_equal 0, Orm::Communication::PushSubscription.count
    end

    test "an address outside the push services is refused with 422" do
      sign_in_as @awa

      post push_subscriptions_path, params: body(endpoint: "https://metadata.google.internal/x"), as: :json

      assert_response :unprocessable_entity
      assert_equal 0, Orm::Communication::PushSubscription.count
    end

    test "the sixth subscription of a student evicts the oldest" do
      sign_in_as @awa
      oldest = create_push_subscription(user: @awa, updated_at: 5.days.ago)
      4.times { create_push_subscription(user: @awa, updated_at: 1.day.ago) }

      post push_subscriptions_path, params: body, as: :json

      assert_response :created
      assert_equal 5, Orm::Communication::PushSubscription.where(user: @awa).count
      assert_not Orm::Communication::PushSubscription.exists?(oldest.id)
    end

    test "the eleventh request of a minute answers 429" do
      sign_in_as @awa
      10.times { post push_subscriptions_path, params: body, as: :json }
      assert_response :created

      post push_subscriptions_path, params: body, as: :json

      assert_response :too_many_requests
    end

    test "a visitor is sent to sign in" do
      post push_subscriptions_path, params: body, as: :json

      assert_redirected_to new_session_path
      assert_equal 0, Orm::Communication::PushSubscription.count
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
  end
end
