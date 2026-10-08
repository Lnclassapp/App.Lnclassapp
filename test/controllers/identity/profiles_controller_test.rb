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
      assert_select "details", text: /Ton code secret protège ton compte/
      assert_modal_link edit_profile_pin_path, /Changer mon code secret/
    end
    assert_select "dt", text: "Établissement", count: 0
  end

  # UDR-0041, amendment of 2026-10-02: the student's profile says each thing once, with no permanent help text.
  test "UDR-0041: the student's profile has no subtitle, no identity block, its photo row shows the avatar" do
    sign_in_as create_student(first_name: "Aya", last_name: "Koné", classroom: create_classroom)

    get profile_path

    assert_select "#main h1", count: 1
    assert_select "#main h1", "Mon profil"
    assert_select "#main p", text: "Ce que Lnclass sait de vous, et ce que vous pouvez changer.", count: 0
    assert_select "#profile_information" do |card|
      assert_equal 1, card.text.scan("Aya Koné").size
      assert_select "p.truncate", 0
      assert_select "*", text: "Élève", count: 0
      assert_select "dl.mt-5.divide-y.divide-line.border-t.border-line.text-sm"
      assert_select "dd span[aria-hidden=true] [role=img][aria-label='Aya Koné']", text: "AK"
      assert_select "dd span.sr-only", "Aucune photo : tes initiales s'affichent."
      assert_select "a[href='#{edit_profile_photo_path}'][data-turbo-frame=modal]", text: /Ajouter une photo/
    end
    assert_select "#profile_security" do
      assert_select "div.flex.flex-wrap.items-center > h2#profile_security_title", "Mon code secret"
      assert_select "details summary .sr-only", "Aide : Mon code secret"
      assert_select "details div", "Ton code secret protège ton compte. Change-le si tu penses qu'une autre personne le connaît."
      assert_select "p", text: /Ton code secret protège ton compte/, count: 0
    end
  end

  # UDR-0041, amendment of 2026-10-06: the student is called « tu » (charter §1), the other roles keep « vous ».
  test "UDR-0041: the student's profile says « tu », never « vous »" do
    sign_in_as create_student(classroom: create_classroom)

    get profile_path

    assert_no_match(/\b(vous|votre|vos)\b/i, css_select("#main").text)
    assert_select "#profile_security details div", "Ton code secret protège ton compte. Change-le si tu penses qu'une autre personne le connaît."
    assert_select "#profile_information dd span.sr-only", "Aucune photo : tes initiales s'affichent."
  end

  # UDR-0041, amendment of 2026-10-06: the student saw three styles (outline 40 px, dark filled, switch).
  test "UDR-0041: the four actions of the student's profile share one button style, 48 px high" do
    sign_in_as create_student(classroom: create_classroom)

    get profile_path

    classes = css_select("#main a[data-turbo-frame=modal]").map { it["class"] }
    assert_equal 4, classes.size
    assert_equal 1, classes.uniq.size, "styles : #{classes.uniq.inspect}"
    # Lot E6 (politique-cache): « md » is the shared class ui-button-md, whose min-h-tap (48 px) shared_classes_test freezes.
    assert_includes classes.first.split, "ui-button-md"
  end

  test "UDR-0041: the student's profile modals say « tu », a teacher's keep « vous »" do
    sign_in_as create_student(classroom: create_classroom)
    { edit_profile_pin_path => "Saisis ton code secret actuel", edit_profile_contact_path => "Tu te connecteras",
      edit_profile_photo_path => "sur ton téléphone", edit_profile_name_path => "Modifier mon nom" }.each do |path, text|
      get path

      assert_select "dialog", text: /#{text}/
      assert_no_match(/\b(vous|votre|vos)\b/i, css_select("dialog").text, path)
    end
    sign_out

    sign_in_as create_teacher
    get edit_profile_pin_path

    assert_select "dialog", text: /Saisissez votre code secret actuel/
  end

  # UDR-0041, amendment of 2026-10-02: the other roles keep the current profile until their own clean-up.
  test "UDR-0041: a teacher, a school admin and a team member keep the subtitle, the identity block and the PIN text" do
    {
      create_teacher(first_name: "Yao", last_name: "Kouassi") => "Enseignant",
      create_school_admin(first_name: "Adjoua", last_name: "Bamba") => "Direction",
      create_team_member(first_name: "Koffi", last_name: "Diallo") => "Équipe"
    }.each do |user, role|
      sign_in_as user

      get profile_path

      name = "#{user.first_name} #{user.last_name}"
      assert_select "#main p", text: "Ce que Lnclass sait de vous, et ce que vous pouvez changer."
      assert_select "#profile_information" do
        assert_select "p.truncate", name
        assert_select "span", text: role
        assert_select "dd:not(.sr-only)", "Aucune photo : vos initiales s'affichent."
        assert_select "dd span.sr-only", 0
      end
      assert_select "#profile_security > h2#profile_security_title", "Mon code secret"
      assert_select "#profile_security p", text: /Votre code secret protège votre compte/
      assert_select "#profile_security details", 0
      sign_out
    end
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

  test "a teacher without a subject reads a dash; without a school, the waiting screen holds them (ADR-0063)" do
    teacher = create_user(role: "teacher")
    Orm::TeacherSchool.create!(teacher:, school: create_school, primary: true)
    sign_in_as teacher

    get profile_path

    assert_response :success
    assert_select "dd", text: "—", count: 1

    Orm::TeacherSchool.where(teacher:).delete_all
    get profile_path
    assert_redirected_to pending_account_path
  end

  test "CP-15: a teacher with 3 colleagues signed up thanks to them wears the « Ambassadeur » badge; with 2, not yet" do
    teacher = create_teacher
    2.times { create_referral(referrer: teacher) }
    sign_in_as teacher

    get profile_path
    assert_select "#profile_ambassador", 0

    create_referral(referrer: teacher)
    get profile_path
    assert_select "#profile_ambassador", text: /#{I18n.t("identity.referrals.ambassador.badge")}/
    assert_select "#profile_ambassador", text: /#{I18n.t("identity.referrals.ambassador.thanks", count: 3)}/
  end

  test "a team member reads their team role and that the second factor is active" do
    sign_in_as create_team_member(team_role: "content")

    get profile_path

    assert_select "dt", text: "Rôle"
    assert_select "dd", text: "Contenu"
    assert_select "#profile_information", text: /Second facteur : actif/
  end

  # DS-03, UDR-0052: no « En attente » badge any more; the school of the management, as for a teacher, and under the name.
  test "a school admin reads their school" do
    sign_in_as create_school_admin(school: create_school(name: "Lycée Moderne de Bouaké"))

    get profile_path

    assert_response :success
    assert_select "#profile_information", text: /Compte en attente/, count: 0
    assert_select "#profile_information div", text: /Établissement\s+Lycée Moderne de Bouaké/
    assert_select "dt", text: "Rôle", count: 0
    assert_select "header", text: /Lycée Moderne de Bouaké/
  end
end
