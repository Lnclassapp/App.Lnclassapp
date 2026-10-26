require "test_helper"

# PR-01, PR-02, ADR-0055, UDR-0041, UDR-0089: « Mon profil » shows the account of the session, and only it, in the shell of its role.
class Identity::ProfilesControllerTest < ActionDispatch::IntegrationTest
  def assert_modal_link(path, text)
    assert_select "a[href='#{path}'][data-turbo-frame=modal]", text:
  end

  test "a visitor is sent to the sign-in" do
    get profile_path

    assert_redirected_to new_session_path
  end

  # CA-E2, CA-K2 (mvp-teacher-student, lot E1) — UDR « écrans élève sans répétition » §3.2: no blue card; « Mes informations »
  # has six rows, the editable ones whole links to their window, « Classe » without action; no PIN, dark mode nor sign-out here.
  test "a student reads six rows without a blue card: three to touch, Classe and Établissement without action" do
    student = create_student(first_name: "Aya", last_name: "Koné", contact: "0701020304",
                             classroom: create_classroom(school: create_school(name: "Lycée Classique d'Abidjan"), name: "3e B"),
                             created_at: Time.zone.local(2026, 9, 1, 10))
    sign_in_as student

    get profile_path

    assert_response :success
    assert_select "aside nav"
    assert_select "#main h1", "Mon profil"
    assert_select "#main p", text: "Ce que Lnclass sait de vous, et ce que vous pouvez changer.", count: 0
    assert_select "#profile_identity, .bg-linear-to-br", 0
    assert_select "#profile_information[aria-labelledby=profile_information_title]" do
      assert_select "#profile_information_title", "Mes informations"
      rows = css_select("#profile_information li").map { it.text.squish }
      assert_equal [ "Photo Aucune photo Ajouter", "Nom Aya Koné Modifier", "Numéro 07 01 02 03 04 Changer", "Classe 3e B",
                     "Établissement Lycée Classique d'Abidjan", "Inscrit·e le 1 septembre 2026" ], rows
      { edit_profile_photo_path => "Ajouter photo, Aucune photo", edit_profile_name_path => "Modifier nom, Aya Koné",
        edit_profile_contact_path => "Changer numéro, 07 01 02 03 04" }.each do |path, label|
        assert_select "li > a.min-h-tap[href='#{path}'][data-turbo-frame=modal][aria-label='#{label}']" do
          assert_select "svg", 2
        end
      end
      # CA-K2: no screen offers to change class.
      assert_select "a[href='#{new_student_classroom_change_path}']", 0
      assert_select "a", 3
    end
  end

  # CA-E2: neither the PIN, nor dark mode, nor « Se déconnecter » on the page (all three are in « Mon compte »).
  test "a student's profile has no PIN section, no dark mode card and no sign-out button" do
    sign_in_as create_student(classroom: create_classroom)

    get profile_path

    assert_select "#profile_security, #profile_theme, #profile_sign_out", 0
    assert_select "#main a[href='#{edit_profile_pin_path}']", 0
    assert_select "#main button[role=switch]", 0
    assert_select "#main form[action='#{session_path}']", 0
    assert_select "#main h2", count: 1, text: "Mes informations"
  end

  # CA-E2: one centred column of 720 px at most, « Accueil » back link, then the title.
  test "a student's profile is one centred column of 720 px" do
    sign_in_as create_student(classroom: create_classroom)

    get profile_path

    assert_select "#student_profile.mx-auto.grid.w-full.max-w-180.grid-cols-1" do
      assert_select "> #profile_information"
    end
    assert_select "#student_profile.lg\\:grid-cols-2", 0
    assert_select "#student_profile a[href='#{student_home_path}']", text: /Accueil/
  end

  # UDR-0041, amendment of 2026-10-06: the student is called « tu » (charter §1), the other roles keep « vous ».
  test "UDR-0041: the student's profile says « tu », never « vous »" do
    sign_in_as create_student(classroom: create_classroom)

    get profile_path

    assert_no_match(/\b(vous|votre|vos)\b/i, css_select("#main").text)
  end

  test "a student with a photo reads « Ta photo » on its row, and no card shows it" do
    student = create_student(first_name: "Aya", last_name: "Koné", classroom: create_classroom)
    attach_photo(student)
    sign_in_as student

    get profile_path

    assert_select "#profile_identity", 0
    assert_select "#profile_information a[href='#{edit_profile_photo_path}'][aria-label='Changer photo, Ta photo']",
                  text: /Photo\s+Ta photo\s+Changer/
  end

  # UDR-0089 §3.4 (CA-4): the student's four windows are phone sheets, 480 px once centred; a teacher's are unchanged.
  test "UDR-0041, UDR-0089: the student's profile windows say « tu » and are phone sheets; a teacher's keep « vous » and the centre" do
    sign_in_as create_student(classroom: create_classroom)
    { edit_profile_pin_path => "Saisis ton code secret actuel", edit_profile_contact_path => "Tu te connecteras",
      edit_profile_photo_path => "sur ton téléphone", edit_profile_name_path => "Modifier mon nom" }.each do |path, text|
      get path

      assert_select "dialog", text: /#{text}/
      assert_select "dialog.dialog-phone-sheet.sm\\:max-w-120[aria-labelledby] > span.sheet-handle", 1
      assert_no_match(/\b(vous|votre|vos)\b/i, css_select("dialog").text, path)
    end
    sign_out

    sign_in_as create_teacher
    get edit_profile_pin_path

    assert_select "dialog", text: /Saisissez votre code secret actuel/
    sign_out

    windows = { edit_profile_pin_path => "profile-pin-modal", edit_profile_contact_path => "contact-change-modal",
                edit_profile_photo_path => "profile-photo-modal", edit_profile_name_path => "profile-name-modal" }
    [ create_teacher, create_school_admin, create_team_member ].each do |user|
      sign_in_as user
      windows.each do |path, id|
        get path

        assert_select "dialog##{id}.sm\\:max-w-sm:not(.dialog-phone-sheet)", 1, "#{user.role} #{path}"
        assert_select "dialog##{id} .sheet-handle", 0
      end
      sign_out
    end
  end

  # UDR-0089 §3.4: a wrong PIN answers 422 in the same phone sheet.
  test "UDR-0089: a wrong current PIN keeps the student's window a phone sheet" do
    sign_in_as create_student(classroom: create_classroom)

    patch profile_pin_path, params: { pin_change: { current_pin: "1357", pin: "1111", pin_confirmation: "1111" } }

    assert_response :unprocessable_entity
    assert_select "dialog#profile-pin-modal.dialog-phone-sheet.sm\\:max-w-120 > span.sheet-handle", 1
    assert_select "dialog#profile-pin-modal [role=alert]", text: /Code secret incorrect/
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
      # UDR-0089 §4: their buttons keep the UDR-0041 styles, and nothing of the student's page appears.
      [ edit_profile_photo_path, edit_profile_name_path, edit_profile_contact_path ].each do |path|
        assert_select "#profile_information a.ui-button-secondary.ui-button-sm[href='#{path}'][data-turbo-frame=modal]", 1
      end
      assert_select "#profile_security a.ui-button-primary[href='#{edit_profile_pin_path}'][data-turbo-frame=modal]", 1
      assert_select "#profile_identity, #main li, form#profile_sign_out", 0
      sign_out
    end
  end

  test "the page takes no identifier: it always shows the account of the session" do
    other = create_student(first_name: "Awa", last_name: "Traoré")
    sign_in_as create_student(first_name: "Aya", last_name: "Koné")

    get profile_path(user_id: other.id, id: other.public_id)

    assert_select "#profile_information li", text: /Nom\s+Aya Koné/
    assert_select "#main", text: /Awa Traoré/, count: 0
  end

  # UDR-0089 §3.6: without a classroom, no « Classe » nor « Établissement » row, and no « Élève en … » in the blue card.
  test "a student without a classroom has no classroom nor school row, and no « Élève en » line" do
    sign_in_as create_student(first_name: "Aya", last_name: "Koné")

    get profile_path

    assert_select "#profile_information li", 4
    assert_select "#profile_information", text: /Classe|Établissement/, count: 0
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
