require "test_helper"

# UDR-0189 §3.8 (amendement du 2026-11-27) : « Enseignant(e) » de l'accueil ouvre /teacher, l'équivalent de /student :
# numéro d'abord, puis le code si le compte existe, sinon l'inscription enseignant ouverte sur le code, le numéro gardé.
class Identity::TeacherEntriesControllerTest < ActionDispatch::IntegrationTest
  def send_number(contact) = post(teacher_entries_path, params: { session: { contact: } })
  def send_pin(pin) = post(teacher_entries_path, params: { session: { pin: } })

  test "/teacher montre le numéro seul, titré « Je suis enseignant(e) », envoyé à /teacher" do
    get new_teacher_entry_path

    assert_response :success
    assert_select "title", "Je suis enseignant(e) · Lnclass"
    assert_select "h1", text: "Je suis enseignant(e)"
    assert_select "form#session-form[action='#{teacher_entries_path}'] input[type=tel][name='session[contact]'][inputmode=numeric][data-controller~='digits-only']"
    assert_select "input[name='session[pin]']", 0
  end

  test "un numéro inscrit ouvre le code en 4 cases ; le bon code connecte l'enseignant" do
    teacher = create_teacher

    send_number teacher.contact
    assert_redirected_to new_teacher_entry_path
    follow_redirect!
    assert_select "h1", text: "Je suis enseignant(e)"
    assert_select "#session-number", text: /#{teacher.contact.scan(/\d{2}/).join(" ")}/
    assert_select "form#session-pin-form[action='#{teacher_entries_path}'][data-controller='identity--pin-pad']" do
      assert_select "#session-pin-boxes [data-identity--pin-pad-target=box]", 4
      assert_select "#session-keypad button[data-digit]", 10
    end
    assert_select "a#session-fix-number[href=?]", new_teacher_entry_path(fresh: 1)

    send_pin "2468"
    assert_redirected_to teacher_home_path
    assert cookies[:session_token].present?
  end

  test "un code faux reste sur /teacher, avec son message au-dessus des cases" do
    send_number create_teacher.contact

    send_pin "1357"

    assert_response :unprocessable_entity
    assert_select "#session-pin-pad #session-pin-error[role=alert]", text: /incorrect/
  end

  test "un numéro sans compte ouvre l'inscription enseignant sur le code, le numéro gardé" do
    send_number "0501020304"

    assert_redirected_to new_teacher_registration_path(confirmed: 1)
    follow_redirect!
    assert_select "main#teacher-signup[data-classroom--signup-steps-start-value='2']"
    assert_select "#teacher-registration-number", text: /05 01 02 03 04/
    assert_select "fieldset[data-step='2'] [data-controller='identity--pin-pad'][data-identity--pin-pad-mode-value='step']" do
      assert_select "#teacher-registration-pin-boxes span", 4
      assert_select "#teacher-registration-continue-2[data-identity--pin-pad-target=submit]"
    end
  end

  test "?fresh=1 oublie le numéro gardé" do
    send_number create_teacher.contact

    get new_teacher_entry_path(fresh: 1)

    assert_select "form#session-form input[name='session[contact]']"
    assert_select "#session-pin-form", 0
  end

  test "connecté, /teacher renvoie à son accueil" do
    sign_in_as create_teacher

    get new_teacher_entry_path

    assert_redirected_to teacher_home_path
  end
end
