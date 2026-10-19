require "application_system_test_case"

# PR-01, PR-03, ADR-0055, UDR-0041: from the account menu, a student opens « Mon profil », reads their information,
# corrects their first name in the modal without a page reload, meets the 422 of an empty name, and their teacher
# then sees the new name in the class list. A teacher and a team member read the information of their role.
# UDR-0089 (CA-3 to CA-6): on a phone the windows rise from the bottom and « Se déconnecter » closes the page; on a
# computer they open in the middle, 480 px at most, and the page has two columns.
class Identity::ProfileTest < ApplicationSystemTestCase
  DESKTOP_VIEWPORT = [ 1280, 900 ].freeze

  # Box of an element and size of the window, measured in the browser once the dialog has stopped sliding.
  def box(selector)
    page.document.synchronize do
      settled = page.evaluate_script("document.getAnimations().every(function (a) { return a.playState === 'finished'; })")
      raise Capybara::ExpectationNotMet, "la fenêtre glisse encore" unless settled
    end
    page.evaluate_script(<<~JS, selector)
      (function (selector) {
        var box = document.querySelector(selector).getBoundingClientRect();
        return { top: box.top, bottom: box.bottom, left: box.left, right: box.right, width: box.width,
                 viewportWidth: window.innerWidth, viewportHeight: window.innerHeight };
      })(arguments[0])
    JS
  end

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

  # The student opens « Mon profil » from the avatar menu (UDR-0084 §3.2), the teacher from the account panel of the
  # avatar (UDR-0082 §3.2), the others from the account menu.
  def open_profile
    if page.has_selector?("header button#avatar-menu-button", wait: 0)
      find("header button#avatar-menu-button").click
      within("#avatar-menu") { click_link I18n.t("shared.navigation.profile") }
    elsif page.has_selector?("header a[aria-controls=account_panel]", wait: 0)
      find("header a[aria-controls=account_panel]").click
      within("dialog#account_panel[open]") { click_link I18n.t("shared.navigation.profile") }
    else
      find("button[aria-controls='account-menu']").click
      find("#account-menu a[role=menuitem]", text: I18n.t("shared.navigation.profile")).click
    end
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
    assert_selector "#profile_security a[aria-label='Changer mon code secret']"

    assert_no_page_reload do
      within("#profile_information") { click_on "Modifier" }
      within "turbo-frame#modal dialog[open]" do
        assert_selector "h2", text: "Modifier mon nom"
        fill_in "profile_name[last_name]", with: " "
        click_on "Enregistrer"

        assert_selector "#profile_name_last_name_error", text: "Le nom est obligatoire."
        assert_field "profile_name[first_name]", with: "Aya"
        fill_in "profile_name[last_name]", with: "Koné"
        fill_in "profile_name[first_name]", with: "Aya Marie"
        click_on "Enregistrer"
      end

      assert_toast "Ton nom est enregistré."
      assert_no_selector "turbo-frame#modal dialog[open]"
      within "#profile_information" do
        assert_text "Aya Marie Koné"
        # UDR-0089 §3.2: the card the Turbo Stream sends back is the student's one, as rows.
        assert_no_selector "p.truncate"
        assert_selector "li", text: "Tle D 1"
      end
      within("#profile_identity") { assert_selector "h2", text: "Aya Marie Koné" }
    end
    assert Orm::AuditEvent.exists?(action: "profile.name_changed", actor_id: @student.id)

    sign_out
    sign_in_as @teacher
    visit classroom_path(@classroom.public_id)
    within("#student_#{@student.public_id}") { assert_text "Aya Marie Koné" }
  end

  # UDR-0089 (CA-1, CA-3, CA-4, CA-5): on a phone, the blue card, rows touched anywhere, windows as sheets, sign-out.
  test "at 390 px, a touch anywhere on a row opens its window as a sheet from the bottom; « Se déconnecter » signs out" do
    sign_in_as @student

    with_mobile_viewport do
      visit profile_path

      assert_selector "h1", text: "Mon profil", count: 1
      within("#profile_identity") { assert_text "Élève en Tle D 1" }
      assert_single_primary_action scope: "#main"
      within("#profile_information") { assert_selector "li", text: "Lycée Classique d'Abidjan" }
      heights = all("#main a[data-turbo-frame=modal]").map { page.evaluate_script("arguments[0].getBoundingClientRect().height", it) }
      assert_equal 4, heights.size
      assert heights.all? { it >= 48 }, "hauteurs : #{heights.inspect}"

      # CA-3: the label of the row, not its « Changer », opens the window.
      within("#profile_information") { find("a[href='#{edit_profile_contact_path}'] span", text: "Numéro", exact_text: true).click }
      assert_selector "dialog#contact-change-modal[open]", visible: true
      sheet = box("dialog#contact-change-modal")
      assert_in_delta sheet["viewportHeight"], sheet["bottom"], 1, "la feuille n'est pas ancrée en bas"
      assert_in_delta sheet["viewportWidth"], sheet["width"], 1, "la feuille ne prend pas toute la largeur"
      within("dialog#contact-change-modal") do
        assert_selector ".sheet-handle", visible: true
        find("button[aria-label='#{I18n.t('components.modal.close')}']").click
      end
      assert_no_selector "dialog#contact-change-modal", visible: true

      find("form#profile_sign_out button").click
      assert_current_path root_path
    end
    visit profile_path
    assert_current_path new_session_path
  end

  # UDR-0089 §3.4, §3.5 (CA-4, CA-6): on a computer, information on the left, PIN and sign-out on the right; the PIN
  # window opens in the middle, 480 px at most, without a handle.
  test "at 1 280 px, two columns, and the PIN window in the middle, 480 px at most" do
    sign_in_as @student

    with_mobile_viewport(DESKTOP_VIEWPORT) do
      visit profile_path

      information, security, sign_out = %w[#profile_information #profile_security #profile_sign_out].map { box(it) }
      assert_operator information["right"], :<, security["left"], "« Mes informations » n'est pas à gauche du code secret"
      assert_in_delta security["top"], information["top"], 1, "les deux colonnes ne commencent pas ensemble"
      assert_operator sign_out["top"], :>, security["bottom"], "« Se déconnecter » n'est pas sous le code secret"
      assert_no_selector "#profile_theme", visible: true

      find("#profile_security a[aria-label='Changer mon code secret']").click
      assert_selector "dialog#profile-pin-modal[open]", visible: true
      window = box("dialog#profile-pin-modal")
      assert_in_delta window["viewportWidth"] / 2.0, (window["left"] + window["right"]) / 2.0, 1, "la fenêtre n'est pas centrée"
      assert_operator window["bottom"], :<, window["viewportHeight"] - 1, "la fenêtre est ancrée en bas"
      assert_operator window["width"], :<=, 480
      assert_operator window["width"], :>, 384, "la fenêtre a gardé la largeur sm"
      within("dialog#profile-pin-modal") { assert_no_selector ".sheet-handle", visible: true }
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
    within("#profile_security") { assert_text "Votre code secret protège votre compte." }
    sign_out

    sign_in_as create_team_member(team_role: "content")
    open_profile
    within "#profile_information" do
      assert_text "Contenu"
      assert_text "Second facteur : actif"
    end
  end
end
