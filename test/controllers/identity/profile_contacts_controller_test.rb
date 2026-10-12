require "test_helper"

# ADR-0055, UDR-0041, PR-04, PR-05, PR-07: the number changes in a modal, under the current PIN and a double entry.
# The profile page belongs to Lot A: its redirection is asserted, never followed.
class Identity::ProfileContactsControllerTest < ActionDispatch::IntegrationTest
  NEW_CONTACT = "0711223344".freeze

  setup do
    @student = create_student(contact: "0101020304", classroom: create_classroom)
    sign_in_as @student
  end

  def change(current_pin: "2468", contact: "07 11 22 33 44", contact_confirmation: NEW_CONTACT, **headers)
    patch profile_contact_path, params: { contact_change: { current_pin:, contact:, contact_confirmation: } },
                                headers: { "Turbo-Frame" => "modal", **headers }
  end

  def assert_nothing_written
    assert_equal "0101020304", @student.reload.contact
    assert_equal 0, Orm::AuditEvent.where(action: "contact.changed").count
  end

  test "the modal asks for the current PIN and the new number twice" do
    get edit_profile_contact_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog h2", text: "Changer mon numéro"
    assert_select "input[type=password][name='contact_change[current_pin]'][inputmode=numeric][autocomplete=current-password][maxlength='4']"
    assert_select "input[type=tel][name='contact_change[contact]'][inputmode=tel][autocomplete=tel][maxlength='15']"
    assert_select "input[type=tel][name='contact_change[contact_confirmation]'][inputmode=tel]"
    assert_select "form#contact-change-form[action='#{profile_contact_path}'] input[name=_method][value=patch]"
    assert_select "button[type=submit][form=contact-change-form]", text: "Changer mon numéro"
  end

  test "opened without the modal frame, the modal is served over the shell" do
    get edit_profile_contact_path

    assert_response :success
    assert_select "turbo-frame#modal [data-modal-open-value=true] dialog#contact-change-modal"
  end

  test "a visitor is sent to the sign-in page" do
    sign_out

    get edit_profile_contact_path

    assert_redirected_to new_session_path
  end

  test "the new number replaces the old one, closes the other sessions and renews the current one" do
    other = create_login_session(user: @student)
    old_token = cookies[:session_token]

    change

    assert_redirected_to profile_path
    assert_response :see_other
    assert_equal "Ton numéro est changé.", flash[:notice]
    assert_equal NEW_CONTACT, @student.reload.contact
    assert_not Orm::Session.exists?(other.id)
    assert_equal 1, Orm::Session.where(user: @student).count
    assert_not_equal old_token, cookies[:session_token]
  end

  test "the renewed session keeps working, and the audit log keeps both numbers masked, never a PIN" do
    change
    get edit_profile_contact_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog#contact-change-modal"
    event = Orm::AuditEvent.find_by!(action: "contact.changed")
    assert_equal [ @student.id, @student.id, "User" ], [ event.actor_id, event.subject_id, event.subject_type ]
    assert_equal({ "from" => "********04", "to" => "********44" }, event.metadata)
    assert_no_match(/2468/, event.attributes.to_json)
  end

  # ADR-0049: the renewed session draws a new CSP nonce. The page reached from the modal frame comes in the shell,
  # with the reload tag, so that Turbo leaves the frame and reloads the document; the toast waits for the reloaded page.
  test "the page reached from the modal after the change reloads the whole document" do
    change
    get edit_profile_contact_path, headers: { "Turbo-Frame" => "modal", "X-Turbo-Request-Id" => "1" }

    assert_select "meta[name=turbo-visit-control][content=reload]"
    assert_select "#toasts", text: /Ton numéro est changé\./
    get edit_profile_contact_path, headers: { "Turbo-Frame" => "modal" }
    assert_select "meta[name=turbo-visit-control]", count: 0
  end

  test "the new number signs in, the old one no longer does" do
    change
    sign_out

    post session_path, params: { session: { contact: "0101020304", pin: "2468" } }
    assert_response :unprocessable_entity
    post session_path, params: { session: { contact: NEW_CONTACT, pin: "2468" } }
    assert_redirected_to student_home_path
  end

  test "a team member keeps the verified second factor on the renewed session" do
    sign_out
    member = create_team_member
    sign_in_as member

    change

    assert_redirected_to profile_path
    get edit_profile_contact_path, headers: { "Turbo-Frame" => "modal" }
    assert_response :success
  end

  test "a wrong PIN re-renders the modal in 422, counts a failed sign-in and writes nothing" do
    other = create_login_session(user: @student)

    change(current_pin: "1357")

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Code secret incorrect."
    assert_select "input[name='contact_change[current_pin]']:not([value])"
    assert_select "input[name='contact_change[contact]'][value='07 11 22 33 44']"
    assert_equal 1, Orm::LoginAttempt.where(contact: "0101020304", succeeded: false).count
    assert Orm::Session.exists?(other.id)
    assert_nothing_written
  end

  test "the wrong PIN that locks the account closes the session and returns to the sign-in page" do
    4.times { create_login_attempt(user: @student) }

    change(current_pin: "1357")

    assert_redirected_to new_session_path
    assert_response :see_other
    assert_match(/\ATrop de tentatives\. Réessayez à/, flash[:alert])
    assert_equal 0, Orm::Session.where(user: @student).count
    assert_empty cookies[:session_token].to_s
    assert_nothing_written
  end

  test "a confirmation that differs is refused under its field, the number is kept, the PIN is emptied" do
    change(contact_confirmation: "0711223345")

    assert_response :unprocessable_entity
    assert_select "#contact_change_contact_confirmation_error", text: "Les deux numéros ne sont pas identiques."
    assert_select "input[name='contact_change[contact_confirmation]'][value='0711223345']"
    assert_select "input[name='contact_change[current_pin]']:not([value])"
    assert_equal 0, Orm::LoginAttempt.where(succeeded: false).count
    assert_nothing_written
  end

  test "a number out of format is refused with the rule of the sign-up" do
    change(contact: "08 11 22 33 44", contact_confirmation: "0811223344")

    assert_response :unprocessable_entity
    assert_select "#contact_change_contact_error", text: /Un numéro ivoirien compte 10 chiffres/
    assert_nothing_written
  end

  test "the current number is refused" do
    change(contact: "01 01 02 03 04", contact_confirmation: "0101020304")

    assert_response :unprocessable_entity
    assert_select "#contact_change_contact_error", text: "C'est déjà le numéro de ce compte."
    assert_nothing_written
  end

  test "a number taken by another account gets the neutral message, and nothing is written" do
    create_teacher(contact: "0500000001")

    change(contact: "0500000001", contact_confirmation: "0500000001")

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Ce numéro ne peut pas être utilisé."
    assert_no_match(/compte|déjà utilisé/, response.body[/<dialog.*<\/dialog>/m])
    assert_nothing_written
  end
end
