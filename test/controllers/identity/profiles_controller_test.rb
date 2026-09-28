require "test_helper"

# PR-01, PR-02, ADR-0055, UDR-0041: « Mon profil » shows the account of the session, and only it, in the shell of its role.
class Identity::ProfilesControllerTest < ActionDispatch::IntegrationTest
  def assert_modal_link(path, text)
    assert_select "a[href='#{path}'][data-turbo-frame=modal]", text:
  end

  test "a visitor is sent to the sign-in" do
    get profile_path

    assert_redirected_to new_session_path
  end

  test "a student reads their name, grouped number, classroom and registration date, with the three actions" do
    student = create_student(first_name: "Aya", last_name: "Koné", contact: "0701020304",
                             classroom: create_classroom(name: "Tle D 1"), created_at: Time.zone.local(2026, 9, 1, 10))
    sign_in_as student

    get profile_path

    assert_response :success
    assert_select "aside nav"
    assert_select "h1", "Mon profil"
    assert_select "#profile_information[aria-labelledby=profile_information_title]" do
      assert_select "#profile_information_title", "Mes informations"
      assert_select "[role=img][aria-label='Aya Koné']"
      assert_select "dd", text: /Aya Koné/
      assert_select "dd", text: /07 01 02 03 04/
      assert_select "dd", text: "Tle D 1"
      assert_select "dd", text: "1 septembre 2026"
      assert_modal_link edit_profile_name_path, /Modifier/
      assert_modal_link edit_profile_contact_path, /Changer mon numéro/
    end
    assert_select "#profile_security" do
      assert_select "p", text: /Votre PIN protège votre compte/
      assert_modal_link edit_profile_pin_path, /Changer mon PIN/
    end
    assert_select "dt", text: "Établissement", count: 0
  end

  test "the page takes no identifier: it always shows the account of the session" do
    other = create_student(first_name: "Awa", last_name: "Traoré")
    sign_in_as create_student(first_name: "Aya", last_name: "Koné")

    get profile_path(user_id: other.id, id: other.public_id)

    assert_select "dd", text: /Aya Koné/
    assert_select "dd", text: /Awa Traoré/, count: 0
  end

  test "a student without a classroom reads « Aucune classe »" do
    sign_in_as create_student

    get profile_path

    assert_select "dd", text: "Aucune classe"
  end

  test "a teacher reads their school and subject, and no classroom" do
    sign_in_as create_teacher(school: create_school(name: "Lycée moderne de Cocody"), material: create_material(name: "SVT"))

    get profile_path

    assert_select "dt", text: "Établissement"
    assert_select "dd", text: "Lycée moderne de Cocody"
    assert_select "dd", text: "SVT"
    assert_select "dt", text: "Classe", count: 0
  end

  test "a teacher without a school nor a subject reads a dash" do
    teacher = create_user(role: "teacher")
    sign_in_as teacher

    get profile_path

    assert_response :success
    assert_select "dd", text: "—", count: 2
  end

  test "a team member reads their team role and that the second factor is active" do
    sign_in_as create_team_member(team_role: "content")

    get profile_path

    assert_select "dt", text: "Rôle"
    assert_select "dd", text: "Contenu"
    assert_select "#profile_information", text: /Second facteur : actif/
  end

  test "a pending school admin reads that the account waits" do
    sign_in_as create_user(role: "school_admin")

    get profile_path

    assert_response :success
    assert_select "#profile_information", text: /Compte en attente/
    assert_select "dt", text: "Rôle", count: 0
  end
end
