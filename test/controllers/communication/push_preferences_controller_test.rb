require "test_helper"

# notifications-push: PATCH /push_preference with intent turn_off | turn_on | postpone, on the student's own account.
module Communication
  class PushPreferencesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @awa = create_student
      sign_in_as @awa
    end

    def preference = Orm::Communication::PushPreference.find_by(user: @awa)

    test "turn_off sets the switch and removes the subscription of this session only, then returns to the profile" do
      here = create_push_subscription(user: @awa, session: Orm::Session.where(user: @awa).last)
      elsewhere = create_push_subscription(user: @awa, session: create_login_session(user: @awa))

      patch push_preference_path, params: { intent: "turn_off" }

      assert_redirected_to profile_path
      assert_not_nil preference.turned_off_at
      assert_not Orm::Communication::PushSubscription.exists?(here.id)
      assert Orm::Communication::PushSubscription.exists?(elsewhere.id)
    end

    test "turn_off answers with a Turbo Stream that replaces the profile row" do
      create_push_subscription(user: @awa)

      patch push_preference_path, params: { intent: "turn_off" }, as: :turbo_stream

      assert_response :success
      assert_select "turbo-stream[action=replace][target=profile_notifications_row]"
    end

    test "turn_on clears the switch" do
      create_push_preference(user: @awa, turned_off_at: Time.current)

      patch push_preference_path, params: { intent: "turn_on" }

      assert_redirected_to profile_path
      assert_nil preference.turned_off_at
    end

    test "turn_on answers with a Turbo Stream that replaces the profile row" do
      create_push_preference(user: @awa, turned_off_at: Time.current)

      patch push_preference_path, params: { intent: "turn_on" }, as: :turbo_stream

      assert_response :success
      assert_select "turbo-stream[action=replace][target=profile_notifications_row]"
      assert_nil preference.turned_off_at
    end

    test "turn_on answers a JSON client without a body" do
      create_push_preference(user: @awa, turned_off_at: Time.current)

      patch push_preference_path, params: { intent: "turn_on" }, as: :json

      assert_response :no_content
      assert_nil preference.turned_off_at
    end

    test "postpone hides the invitation for seven days" do
      freeze_time do
        patch push_preference_path, params: { intent: "postpone" }

        assert_response :redirect
        assert_equal 7.days.from_now.to_i, preference.invitation_postponed_until.to_i
      end
    end

    test "postpone answers a Turbo Stream that removes the card" do
      patch push_preference_path, params: { intent: "postpone" }, as: :turbo_stream

      assert_response :success
      assert_select "turbo-stream[action=remove][target=push_invitation]"
    end

    test "an unknown or missing intent is refused and writes nothing" do
      patch push_preference_path, params: { intent: "explode" }
      assert_response :unprocessable_entity

      patch push_preference_path
      assert_response :unprocessable_entity
      assert_nil preference
    end

    test "a teacher, the school management and a team member are refused for every intent and nothing is written" do
      [ create_teacher, create_school_admin, create_team_member ].each do |other|
        delete session_path
        sign_in_as other

        %w[turn_off turn_on postpone].each do |intent|
          patch push_preference_path, params: { intent: }

          assert_response :forbidden, "#{other.class} #{intent}"
        end
      end
      assert_equal 0, Orm::Communication::PushPreference.count
    end
  end
end
