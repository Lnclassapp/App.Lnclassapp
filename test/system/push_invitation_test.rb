require "application_system_test_case"

# notifications-push (UDR §3.1, §3.2): after a first pass the student sees the card, taps « Oui », a subscription exists for
# their session; « Couper » on the profile removes it and the card never comes back. The browser's own push service is stubbed:
# no real permission box and no network call to a push provider.
class PushInvitationTest < ApplicationSystemTestCase
  STUB = <<~JS.freeze
    Notification.requestPermission = async () => "granted"
    PushManager.prototype.subscribe = async () => ({
      toJSON: () => ({ endpoint: "https://fcm.googleapis.com/fcm/send/system-test", keys: { p256dh: "BPsystem", auth: "authsystem" } })
    })
    PushManager.prototype.getSubscription = async () => null
  JS

  setup do
    @previous_key = ENV["VAPID_PUBLIC_KEY"]
    ENV["VAPID_PUBLIC_KEY"] = "BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkrxZJjSgSnfckjBJuBkr3qBUYIHBQFLXYp5Nksh8U"
    @exercise = create_exercise(questions: 2)
    @awa = create_student_for(@exercise.essential.course)
    @passed = create_exercise_session(student: @awa, exercise: @exercise, status: "completed", score_percent: 60)
    sign_in_as @awa
  end

  teardown { ENV["VAPID_PUBLIC_KEY"] = @previous_key }

  test "the card leads to a subscription of the session, and « Couper » removes it for good" do
    visit exercise_session_result_path(@passed.public_id)
    page.execute_script(STUB)

    within "#push_invitation" do
      assert_text I18n.t("communication.push_subscriptions.invitation.title")
      click_on I18n.t("communication.push_subscriptions.invitation.accept")
      assert_text I18n.t("communication.push_subscriptions.invitation.success")
    end

    row = Orm::Communication::PushSubscription.find_by!(endpoint: "https://fcm.googleapis.com/fcm/send/system-test")
    assert_equal @awa.id, row.user_id
    assert_not_nil row.session_id

    visit profile_path
    within "#profile_notifications_row" do
      assert_text I18n.t("identity.profiles.push_row.activated")
      click_on I18n.t("identity.profiles.push_row.turn_off")
      assert_text I18n.t("identity.profiles.push_row.cut")
    end
    assert_not Orm::Communication::PushSubscription.exists?(row.id)

    visit exercise_session_result_path(@passed.public_id)
    assert_no_selector "#push_invitation", visible: :all
  end

  test "« Plus tard » removes the card and it stays away" do
    visit exercise_session_result_path(@passed.public_id)

    within("#push_invitation") { click_on I18n.t("communication.push_subscriptions.invitation.later") }
    assert_no_selector "#push_invitation"

    visit exercise_session_result_path(@passed.public_id)
    assert_no_selector "#push_invitation", visible: :all
  end
end
