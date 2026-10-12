require "test_helper"

# PR-06, PR-07, ADR-0055, UDR-0041: the PIN changes in the modal under the current PIN; a refusal re-renders the modal in
# 422 with every PIN field empty; a success replaces every session with a new one and audits « pin.changed » without any
# data; the lockout closes the session and returns to the sign-in. No PIN ever reaches the response or the audit log.
class Identity::ProfilePinsControllerTest < ActionDispatch::IntegrationTest
  PINS = %w[2468 1357 9753 1358].freeze

  setup { @teacher = create_teacher }

  def change_pin(current_pin: "2468", pin: "1357", pin_confirmation: pin, **options)
    patch profile_pin_path, params: { pin_change: { current_pin:, pin:, pin_confirmation: } }, **options
  end

  def assert_no_pin_in_response
    PINS.each { assert_no_match(/value="#{it}"/, response.body) }
    assert_select "input[type=password][value]", 0
  end

  def assert_pin_kept
    assert Orm::User.authenticate_by(contact: @teacher.contact, pin: "2468")
    assert_not Orm::AuditEvent.exists?(action: "pin.changed")
  end

  test "a visitor is sent to the sign-in" do
    get edit_profile_pin_path
    assert_redirected_to new_session_path

    change_pin
    assert_redirected_to new_session_path
    assert_pin_kept
  end

  test "the form opens in the modal frame: current PIN, new PIN and its confirmation, as numeric secrets" do
    sign_in_as @teacher

    get edit_profile_pin_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog#profile-pin-modal[aria-labelledby]"
    assert_select "form#profile-pin-form[action='#{profile_pin_path}'][method=post]" do
      assert_select "input[name=_method][value=patch]"
      assert_select "input[type=password][name='pin_change[current_pin]'][autocomplete=current-password][inputmode=numeric][maxlength='4'][required]"
      %w[pin pin_confirmation].each do |field|
        assert_select "input[type=password][name='pin_change[#{field}]'][autocomplete=new-password][inputmode=numeric][maxlength='4'][required]"
      end
    end
    assert_select "button[type=submit][form=profile-pin-form]", "Changer mon code secret"
  end

  test "without a frame, the same modal opens on the shell" do
    sign_in_as @teacher

    get edit_profile_pin_path

    assert_response :success
    assert_select "main#main turbo-frame#modal dialog#profile-pin-modal"
  end

  test "the new PIN is set, a new session replaces every other one, and the change is audited without any data" do
    create_login_session(user: @teacher)
    sign_in_as @teacher
    before = Orm::Session.where(user: @teacher).pluck(:id)

    change_pin

    assert_redirected_to profile_path
    assert_response :see_other
    assert_equal "Votre code secret est changé.", flash[:notice]
    assert flash[Authentication::RELOAD_FLASH], "la session renouvelée recharge la page d'arrivée (ADR-0049)"
    assert_no_pin_in_response
    assert Orm::User.authenticate_by(contact: @teacher.contact, pin: "1357")
    assert_not Orm::User.authenticate_by(contact: @teacher.contact, pin: "2468")
    assert_equal 2, before.size
    assert_empty Orm::Session.where(user: @teacher).pluck(:id) & before
    assert_equal 1, Orm::Session.where(user: @teacher).count
    event = Orm::AuditEvent.find_by!(action: "pin.changed")
    assert_equal [ @teacher.id, "User", @teacher.id, {} ], [ event.actor_id, event.subject_type, event.subject_id, event.metadata ]
    Orm::AuditEvent.find_each { |audit| PINS.each { |pin| assert_no_match(pin, audit.metadata.to_json) } }

    get edit_profile_pin_path
    assert_response :success
  end

  test "a team member keeps the verified second factor of the current session" do
    member = create_team_member
    sign_in_as member

    patch profile_pin_path, params: { pin_change: { current_pin: "2468", pin: "1357", pin_confirmation: "1357" } }

    assert_redirected_to profile_path
    get edit_profile_pin_path
    assert_response :success
  end

  test "a wrong current PIN is refused in the modal and counts as a failed sign-in" do
    sign_in_as @teacher

    change_pin(current_pin: "9753", headers: { "Turbo-Frame" => "modal" })

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal dialog#profile-pin-modal"
    assert_select "[role=alert]", text: "Code secret incorrect."
    assert_select "#pin_change_current_pin_error", 0
    assert_no_pin_in_response
    assert_pin_kept
    assert Orm::LoginAttempt.exists?(contact: @teacher.contact, succeeded: false, kind: "pin")
  end

  test "a confirmation that differs, a PIN out of format and the current PIN are refused in 422, fields emptied" do
    sign_in_as @teacher
    {
      { pin_confirmation: "1358" } => [ "pin_confirmation", "Les deux codes secrets ne sont pas identiques." ],
      { pin: "13579", pin_confirmation: "13579" } => [ "pin", "Le code secret compte 4 chiffres." ],
      { pin: "", pin_confirmation: "" } => [ "pin", "Le nouveau code secret, à 4 chiffres, est obligatoire." ],
      { current_pin: "" } => [ "current_pin", "Le code secret actuel est obligatoire." ],
      { pin: "2468" } => [ "pin", "C'est déjà le code secret de ce compte." ]
    }.each do |entry, (field, message)|
      change_pin(**entry)

      assert_response :unprocessable_entity
      assert_select "#pin_change_#{field}_error", text: message
      assert_no_pin_in_response
    end
    assert_pin_kept
  end

  test "the failure that locks the account closes the session and returns to the sign-in with the lockout message" do
    other = create_login_session(user: @teacher)
    sign_in_as @teacher
    4.times { create_login_attempt(user: @teacher) }

    change_pin(current_pin: "9753")

    assert_redirected_to new_session_path
    assert_response :see_other
    assert_match(/\ATrop de tentatives\. Réessayez à \d\d h \d\d\.\z/, flash[:alert])
    assert flash[Authentication::RELOAD_FLASH]
    assert_equal [ other.id ], Orm::Session.where(user: @teacher).pluck(:id)
    assert Orm::AuditEvent.exists?(action: "login.locked", subject_id: @teacher.id)
    assert_pin_kept

    get edit_profile_pin_path
    assert_redirected_to new_session_path
  end

  # From the modal, Turbo follows the redirect inside the frame: the minimal frame layout must reload the whole document
  # (ADR-0049), or the sign-in would land in a frame it does not contain (« Content missing »).
  test "the sign-in reached from the modal after the lockout reloads the whole document" do
    sign_in_as @teacher
    4.times { create_login_attempt(user: @teacher) }
    frame = { "Turbo-Frame" => "modal", "X-Turbo-Request-Id" => SecureRandom.uuid }

    change_pin(current_pin: "9753", headers: frame)
    follow_redirect!(headers: frame)

    assert_response :success
    assert_select "head meta[name=turbo-visit-control][content=reload]"
    assert_select "#session-form"
  end
end
