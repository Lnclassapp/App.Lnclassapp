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

  # UDR-0089 §3.1, §3.2 (CA-1, CA-2, CA-3): the blue card, then « Mes informations » as whole rows to touch.
  test "a student reads the blue card, then their information as rows, the editable ones whole links to their window" do
    student = create_student(first_name: "Aya", last_name: "Koné", contact: "0701020304",
                             classroom: create_classroom(school: create_school(name: "Lycée Classique d'Abidjan"), name: "3e B"),
                             created_at: Time.zone.local(2026, 9, 1, 10))
    sign_in_as student

    get profile_path

    assert_response :success
    assert_select "aside nav"
    assert_select "#main h1", "Mon profil"
    assert_select "#main p", text: "Ce que Lnclass sait de vous, et ce que vous pouvez changer.", count: 0
    assert_select "#profile_identity.rounded-card.bg-linear-to-br.from-brand-strong.to-brand.text-white" do
      assert_select "span[aria-hidden=true] [role=img][aria-label='Aya Koné']", text: "AK"
      assert_select "span[aria-hidden=true]", text: "+"
      assert_select "h2#profile_identity_name", "Aya Koné"
      assert_select "p", "Élève en 3e B"
      assert_select "a, button", 0
    end
    assert_select "#profile_information[aria-labelledby=profile_information_title]" do
      assert_select "#profile_information_title", "Mes informations"
      rows = css_select("#profile_information li").map { it.text.squish }
      assert_equal [ "Photo Aucune photo Ajouter", "Nom Aya Koné Modifier", "Numéro 07 01 02 03 04 Changer", "Classe 3e B",
                     "Établissement Lycée Classique d'Abidjan", "Inscrit le 1 septembre 2026" ], rows
      { edit_profile_photo_path => "Ajouter photo, Aucune photo", edit_profile_name_path => "Modifier nom, Aya Koné",
        edit_profile_contact_path => "Changer numéro, 07 01 02 03 04" }.each do |path, label|
        assert_select "li > a.min-h-tap[href='#{path}'][data-turbo-frame=modal][aria-label='#{label}']" do
          assert_select "svg", 2
        end
      end
      assert_select "a", 3
    end
  end

  # UDR-0089 §3.3 (CA-5): the PIN row opens its window, « Se déconnecter » is a real form button at the bottom.
  test "a student changes their PIN from its row, and signs out from the button at the bottom of the page" do
    sign_in_as create_student(classroom: create_classroom)

    get profile_path

    assert_select "#profile_security" do
      assert_select "h2#profile_security_title", "Mon code secret"
      assert_select "p", "Ton code secret protège ton compte. Ne le donne à personne, même à un ami."
      assert_select "a.min-h-tap[href='#{edit_profile_pin_path}'][data-turbo-frame=modal][aria-label='Changer mon code secret']",
                    text: /Code à 4 chiffres\s+••••\s+Changer/
      assert_select "details", 0
    end
    assert_select "form#profile_sign_out[action='#{session_path}'][method=post]" do
      assert_select "input[name=_method][value=delete]", 1
      assert_select "button[type=submit].ui-button-secondary.w-full", text: "Se déconnecter" do
        assert_select "svg", 1
      end
    end
    assert_equal "profile_sign_out", css_select("#main [id^=profile_]").last["id"], "« Se déconnecter » ferme la page"
    assert_select "#profile_theme", 1
  end

  # UDR-0089 §3.5 (CA-6): one column of 720 px, then two in 960 px from 1 024 px, the blue card across both.
  test "a student's profile is one centred column, two from lg: information on the left, PIN and sign-out on the right" do
    sign_in_as create_student(classroom: create_classroom)

    get profile_path

    assert_select "#student_profile.mx-auto.grid.w-full.max-w-180.grid-cols-1.lg\\:max-w-240.lg\\:grid-cols-2" do
      assert_select "> #profile_identity.lg\\:col-span-2"
      assert_select "> #profile_information"
      assert_select "> div > #profile_security + div > #profile_theme"
      assert_select "> div > #profile_sign_out"
    end
  end

  # UDR-0041, amendment of 2026-10-06: the student is called « tu » (charter §1), the other roles keep « vous ».
  test "UDR-0041: the student's profile says « tu », never « vous »" do
    sign_in_as create_student(classroom: create_classroom)

    get profile_path

    assert_no_match(/\b(vous|votre|vos)\b/i, css_select("#main").text)
  end

  test "a student with a photo reads « Ta photo » and sees it in the blue card, without the « + »" do
    student = create_student(first_name: "Aya", last_name: "Koné", classroom: create_classroom)
    attach_photo(student)
    sign_in_as student

    get profile_path

    assert_select "#profile_identity img[alt='Aya Koné']", 1
    assert_select "#profile_identity", text: /\+/, count: 0
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
    assert_select "dialog#profile-pin-modal.sm\\:max-w-sm:not(.dialog-phone-sheet)", 1
    assert_select "dialog#profile-pin-modal .sheet-handle", 0
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

    assert_select "#profile_identity h2", "Aya Koné"
    assert_select "#main", text: /Awa Traoré/, count: 0
  end

  # UDR-0089 §3.6: without a classroom, no « Classe » nor « Établissement » row, and no « Élève en … » in the blue card.
  test "a student without a classroom has no classroom nor school row, and no « Élève en » line" do
    sign_in_as create_student(first_name: "Aya", last_name: "Koné")

    get profile_path

    assert_select "#profile_identity p", 0
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
