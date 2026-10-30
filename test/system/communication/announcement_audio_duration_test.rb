require "application_system_test_case"

# LA-6 (chantier annonces-logo-audio, UDR-0071 amendement du 2026-10-30 §3.8), in a real browser: the author chooses an
# audio of 11 s, the browser reads its duration and says so under the field (the field is invalid, the form is not sent);
# he chooses one of 9 s, the message goes and the form is sent. The server measures again whatever happens
# (authored_messages_controller_test).
class Communication::AnnouncementAudioDurationTest < ApplicationSystemTestCase
  # The browser reads the duration of the stream (11 s, or 11,1 s with the encoder delay), the server counts the frames.
  TOO_LONG = /\ACet audio dure 11(,\d)? s : 10 secondes au plus\. Raccourcissez l'enregistrement\.\z/

  setup do
    pilot_flags!(teacher_announcements_enabled: true)
    school = create_school(name: "Collège Les Lauriers")
    @classroom = create_classroom(school:, name: "3ème B")
    @teacher = create_teacher(school:, material: create_material(name: "SVT"), classrooms: [ @classroom ], gender: "male", last_name: "Kouassi")
  end

  def field(attribute) = Dtos::Communication::MessageInput.human_attribute_name(attribute)
  def form_valid? = page.evaluate_script("document.getElementById('announcement_audio').form.checkValidity()")
  def custom_error? = page.evaluate_script("document.getElementById('announcement_audio').validity.customError")

  test "LA-6 — an audio of 11 s: the message under the field, the field invalid, nothing sent; then one of 9 s: the message is gone, it is sent" do
    sign_in_as @teacher
    visit new_announcement_path
    fill_in field(:title), with: "Réunion de rentrée"
    fill_in field(:body), with: "Le détail est dans l'audio."
    find("label", text: "3ème B").click

    attach_file field(:audio), file_fixture("audio/duree-11s.mp3")

    assert_selector "[data-communication--audio-duration-target=status]", text: TOO_LONG
    assert custom_error?
    assert_equal false, form_valid?
    click_button I18n.t("communication.authored_messages.form.publish")
    assert_current_path new_announcement_path

    attach_file field(:audio), file_fixture("audio/duree-9s.mp3")

    assert_no_selector "[data-communication--audio-duration-target=status]", text: TOO_LONG
    assert_equal false, custom_error?
    assert_equal true, form_valid?
    click_button I18n.t("communication.authored_messages.form.publish")
    assert_current_path my_announcements_path
    assert_equal "audio/mpeg", Orm::Message.last.audio.content_type
  end
end
