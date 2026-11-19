require "test_helper"

# notifications-push (UDR §3.1, §3.2): the card under a passed result and the « Notifications » row of the profile are rendered
# only when the server decides so; with no public VAPID key, nothing is rendered.
module Communication
  class PushInvitationViewsTest < ActionDispatch::IntegrationTest
    ANDROID = "Hotwire Native Android; LnclassStudentAndroid/1.0".freeze

    setup do
      @exercise = create_exercise(questions: 2)
      @awa = create_student_for(@exercise.essential.course)
      @passed = create_exercise_session(student: @awa, exercise: @exercise, status: "completed", score_percent: 60)
      @failed = create_exercise_session(student: @awa, exercise: @exercise, status: "completed", score_percent: 20)
      @previous_key = ENV["VAPID_PUBLIC_KEY"]
      ENV["VAPID_PUBLIC_KEY"] = "BPublicKeyForTests"
      sign_in_as @awa
    end

    teardown { ENV["VAPID_PUBLIC_KEY"] = @previous_key }

    def card = css_select("section#push_invitation")

    test "a passed copy shows the hidden card with the key, the urls and the three bullets" do
      get exercise_session_result_path(@passed.public_id)

      assert_select "section#push_invitation[hidden][data-controller=push-subscription][data-push-subscription-vapid-key-value=BPublicKeyForTests]"
      assert_select "section#push_invitation[data-push-subscription-subscriptions-url-value=?]", push_subscriptions_path
      assert_select "section#push_invitation li", 3
      assert_select "section#push_invitation form[action=?] input[name=intent][value=postpone]", push_preference_path
    end

    test "a failed copy shows no card" do
      get exercise_session_result_path(@failed.public_id)

      assert_response :success
      assert_empty card
    end

    test "no public key, no card" do
      ENV["VAPID_PUBLIC_KEY"] = nil
      get exercise_session_result_path(@passed.public_id)

      assert_empty card
    end

    test "a subscription, a switch off or a recent « plus tard » hides the card" do
      row = create_push_subscription(user: @awa)
      get exercise_session_result_path(@passed.public_id)
      assert_empty card

      row.destroy!
      pref = create_push_preference(user: @awa, invitation_postponed_until: 3.days.from_now)
      get exercise_session_result_path(@passed.public_id)
      assert_empty card

      pref.update!(invitation_postponed_until: nil, turned_off_at: Time.current)
      get exercise_session_result_path(@passed.public_id)
      assert_empty card
    end

    test "the Android shell gets no card" do
      get exercise_session_result_path(@passed.public_id), headers: { "User-Agent" => ANDROID }

      assert_response :success
      assert_empty card
    end

    test "the teacher reading the copy sees no card" do
      delete session_path
      teacher = create_teacher(classrooms: [ create_classroom(school: Orm::School.first || create_school) ])
      sign_in_as teacher
      get exercise_session_result_path(@passed.public_id)

      assert_empty card
    end

    test "the profile has no row before a first yes" do
      get profile_path

      assert_response :success
      assert_select "#profile_notifications_row", 0
    end

    test "the profile row says activated with « Couper » once subscribed" do
      create_push_subscription(user: @awa)
      get profile_path

      assert_select "#profile_notifications_row[data-push-subscription-state-value=on]" do
        assert_select "[data-push-subscription-target=value]", text: I18n.t("identity.profiles.push_row.activated")
        assert_select "form[action=?] input[name=intent][value=turn_off]", push_preference_path
      end
    end

    test "the profile row says off with « Réactiver » once cut" do
      create_push_preference(user: @awa, turned_off_at: Time.current)
      get profile_path

      assert_select "#profile_notifications_row[data-push-subscription-state-value=off]" do
        assert_select "[data-push-subscription-target=value]", text: I18n.t("identity.profiles.push_row.cut")
        assert_select "form input[name=intent][value=turn_on]"
      end
    end

    test "no row without a key or in the Android shell" do
      create_push_subscription(user: @awa)
      get profile_path, headers: { "User-Agent" => ANDROID }
      assert_select "#profile_notifications_row", 0

      ENV["VAPID_PUBLIC_KEY"] = nil
      get profile_path
      assert_select "#profile_notifications_row", 0
    end
  end
end
