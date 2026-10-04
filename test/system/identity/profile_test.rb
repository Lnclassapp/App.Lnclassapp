require "application_system_test_case"

# PR-01, PR-03, ADR-0055, UDR-0041: from the account menu, a student opens « Mon profil », reads their information,
# corrects their first name in the modal without a page reload, meets the 422 of an empty name, and their teacher
# then sees the new name in the class list. A teacher and a team member read the information of their role.
class Identity::ProfileTest < ApplicationSystemTestCase
  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school:, name: "Tle D 1")
    @teacher = create_teacher(school:, material: create_material(name: "SVT"), classrooms: [ @classroom ], first_name: "Yao")
    @student = create_student(classroom: @classroom, first_name: "Aya", last_name: "Koné", contact: "0701020304",
                              created_at: Time.zone.local(2026, 9, 1, 10))
  end

# UDR-0065, amendement du 2026-10-03 : sur grand écran, l'interrupteur à côté de l'avatar passe la page en sombre sans
# la recharger, et le choix tient au chargement suivant (cookie) ; un second clic revient au clair.
test "the switch next to the avatar turns the page dark at once, and the choice survives a reload" do
  sign_in_as @student
  background = -> { page.evaluate_script("getComputedStyle(document.body).backgroundColor") }
  switch = -> { find("header button[role=switch]") }

  assert_equal "rgb(250, 248, 244)", background.call
  switch.call.click

  assert_selector "html[data-theme=dark]"
  assert_equal "rgb(15, 18, 24)", background.call
  assert_equal "true", switch.call["aria-checked"]

  visit current_path

  assert_equal "rgb(15, 18, 24)", background.call
  switch.call.click

  assert_selector "html[data-theme=light]"
  assert_equal "rgb(250, 248, 244)", background.call
end

  def open_profile
    find("button[aria-controls='account-menu']").click
    find("#account-menu a[role=menuitem]", text: I18n.t("shared.navigation.profile")).click
    assert_current_path profile_path
  end

  test "the student reads their profile, then corrects their first name without a page reload; the teacher sees it" do
    sign_in_as @student
    open_profile

    within "#profile_information" do
      assert_text "Aya Koné"
      assert_text "07 01 02 03 04"
      assert_text "Tle D 1"
      assert_text "1 septembre 2026"
    end
    assert_selector "#profile_security a", text: "Changer mon PIN"

    assert_no_page_reload do
      within("#profile_information") { click_on "Modifier" }
      within "turbo-frame#modal dialog[open]" do
        assert_selector "h2", text: "Modifier mon nom"
        fill_in "profile_name[last_name]", with: " "
        click_on "Enregistrer"

        assert_selector "#profile_name_last_name_error", text: "Saisissez votre nom."
        assert_field "profile_name[first_name]", with: "Aya"
        fill_in "profile_name[last_name]", with: "Koné"
        fill_in "profile_name[first_name]", with: "Aya Marie"
        click_on "Enregistrer"
      end

      assert_toast "Votre nom est enregistré."
      assert_no_selector "turbo-frame#modal dialog[open]"
      within "#profile_information" do
        assert_text "Aya Marie Koné"
        # UDR-0041, amendment of 2026-10-02: the card the Turbo Stream sends back is the pared-down one too.
        assert_no_selector "p.truncate"
        assert_no_text "Élève"
      end
    end
    assert Orm::AuditEvent.exists?(action: "profile.name_changed", actor_id: @student.id)

    sign_out
    sign_in_as @teacher
    visit classroom_path(@classroom.public_id)
    within("#student_#{@student.public_id}") { assert_text "Aya Marie Koné" }
  end

  # UDR-0041, amendment of 2026-10-02: R1 to R6 on the student's profile, on a phone.
  test "at 390 px, the student's profile shows three blocks, one primary action, its PIN help on demand" do
    sign_in_as @student

    with_mobile_viewport do
      visit profile_path

      assert_selector "h1", text: "Mon profil", count: 1
      assert_no_text "Ce que Lnclass sait de vous"
      assert_single_primary_action scope: "#main"
      assert_blocks_above_fold "#main > div > *", max: 3
      within "#profile_information" do
        assert_text "Aya Koné", count: 1
        assert_no_text "Élève"
        # The sentence is left to screen readers: a 1 px box, the avatar shows the initials instead.
        phrase = find("dd span.sr-only", text: "Aucune photo : vos initiales s'affichent.")
        assert_operator page.evaluate_script("arguments[0].getBoundingClientRect().width", phrase), :<=, 1
        assert_selector "dd span[aria-hidden=true] [role=img]", text: "AK"
        assert_link "Ajouter une photo"
      end
      within "#profile_security" do
        assert_no_text "Votre PIN protège votre compte."
        find("details summary", text: "Aide : Mon PIN").click
        assert_text "Votre PIN protège votre compte. Changez-le si vous pensez qu'une autre personne le connaît."
        assert_link "Changer mon PIN"
      end
    end
  end

  test "a teacher reads their school and subject, a team member their role and active second factor" do
    sign_in_as @teacher
    open_profile
    # UDR-0041, amendment of 2026-10-02: the teacher's profile is unchanged.
    assert_text "Ce que Lnclass sait de vous, et ce que vous pouvez changer."
    within "#profile_information" do
      assert_selector "p.truncate", text: "Yao"
      assert_text "Enseignant"
      assert_text "Aucune photo : vos initiales s'affichent."
      assert_text "Lycée Classique d'Abidjan"
      assert_text "SVT"
    end
    within("#profile_security") { assert_text "Votre PIN protège votre compte." }
    sign_out

    sign_in_as create_team_member(team_role: "content")
    open_profile
    within "#profile_information" do
      assert_text "Contenu"
      assert_text "Second facteur : actif"
    end
  end
end
