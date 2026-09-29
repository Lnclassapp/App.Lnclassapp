require "application_system_test_case"

# Finitions UX, Lot A (UDR-0054, UDR-0009, UDR-0019): the public pages in Chrome — the tab title, the logo that leads to
# the public home, the arrival focus and the focus after a 422, /join sent at the fifth valid character, and the
# invitation that ends on « Se connecter » with the number filled in, used once.
module Finitions; end

class Finitions::PublicPagesTest < ApplicationSystemTestCase
  INVITEE = "0100000009".freeze

  setup do
    create_classroom(name: "6ème 1", join_code: "kfm37")
    @invitation = create_invitation(contact: INVITEE)
  end

  test "FU-03: the sign-in page is « Connexion · Lnclass »" do
    visit new_session_path

    assert_title "Connexion · Lnclass"
  end

  test "FU-13: the logo of each public page leads to the public home" do
    [ new_session_path, new_join_code_path, join_classroom_path("KFM37"), new_teacher_registration_path,
      new_pending_teacher_registration_path, invitation_path(@invitation.token), new_identity_pin_reset_path ].each do |path|
      visit path
      find("a[aria-label='Lnclass, accueil']").click

      assert_current_path root_path, ignore_query: true
    end
  end

  test "FU-13: at 390 px, the logo shown above the form leads home too" do
    with_mobile_viewport do
      visit invitation_path(@invitation.token)
      find("a[aria-label='Lnclass, accueil']").click

      assert_current_path root_path
    end
  end

  test "FU-13: « PIN oublié » goes back to « Se connecter » by the back link" do
    visit new_identity_pin_reset_path

    within("nav[aria-label='Retour']") { click_link "Se connecter" }

    assert_current_path new_session_path
  end

  test "FU-19: the arrival focus is on the number on /login and on the code on /join" do
    visit new_session_path
    assert_selector "#session_contact:focus"

    visit new_join_code_path
    assert_selector "#join_code:focus"
  end

  test "FU-19: /c/<code> and /teacher-signup leave the focus to the browser" do
    [ join_classroom_path("KFM37"), new_teacher_registration_path ].each do |path|
      visit path
      # The eye of the PIN field is shown by its controller: Stimulus is connected, the autofocus controller too.
      assert_selector "[data-password-reveal-target=toggle]", minimum: 1

      assert_equal "BODY", page.evaluate_script("document.activeElement.tagName"), path
    end
  end

  test "FU-17: /c/<code> sent without a first name comes back in 422 with the focus on the field in error" do
    visit join_classroom_path("KFM37")
    without_browser_validation("#join-form")
    fill_in "join[last_name]", with: "Kouassi"
    choose I18n.t("genders.female")
    fill_in "join[contact]", with: "07 01 02 03 04"
    fill_in "join[pin]", with: "4821"
    fill_in "join[pin_confirmation]", with: "4821"
    click_on I18n.t("classroom.joins.signup_form.submit")

    assert_selector "#join_first_name_error"
    assert_selector "#join_first_name[aria-invalid=true]:focus"
    assert_equal 0, Orm::User.count
  end

  test "FU-44: /join sends a well-formed code by itself, and nothing before" do
    visit new_join_code_path
    count_submits

    fill_in "join[code]", with: "kfm3"
    fill_in "join[code]", with: "kio37"
    assert_equal 0, page.evaluate_script("window.lotASubmits")
    assert_current_path new_join_code_path

    fill_in "join[code]", with: "kfm37"

    assert_current_path join_classroom_path("kfm37")
    assert_selector "#classroom-preview", text: "6ème 1"
    assert_equal 1, page.evaluate_script("window.lotASubmits")
  end

  test "FU-30, FU-31: the invitee lands on « Se connecter », number filled in, PIN empty and focused, no session" do
    visit invitation_path(@invitation.token)
    assert_title "Créer mon compte · Lnclass"
    assert_selector "#invitation_last_name:focus"
    assert_no_field "invitation[contact]"

    accept_invitation

    assert_selector "#session-form", wait: SIGN_IN_WAIT
    assert_toast "Votre compte est créé."
    assert_field "session[contact]", with: "01 00 00 00 09"
    assert_field "session[pin]", with: ""
    assert_selector "#session_pin:focus"
    assert_no_match(/0100000009|01%2000/, page.current_url)
    assert_no_selector "#toasts", text: /01 00 00 00 09|0100000009/
    assert_equal 0, Orm::Session.count
  end

  test "FU-32: a reload forgets the number; a school admin invitation also ends on the filled-in sign-in, then « Travail des élèves »" do
    visit invitation_path(@invitation.token)
    accept_invitation
    assert_field "session[contact]", with: "01 00 00 00 09", wait: SIGN_IN_WAIT

    visit new_session_path
    assert_field "session[contact]", with: ""
    assert_selector "#session_contact:focus"

    school_invitation = create_invitation(kind: "school_staff", contact: "0500000007")
    visit invitation_path(school_invitation.token)
    accept_invitation
    assert_field "session[contact]", with: "05 00 00 00 07", wait: SIGN_IN_WAIT
    fill_in "session[pin]", with: "4821"
    click_on I18n.t("identity.sessions.new.submit")

    assert_current_path school_admin_classrooms_path, wait: SIGN_IN_WAIT
    assert_selector "h1", text: "Travail des élèves"
  end

  test "FU-33: an invitation sent without a name comes back in 422, focus on « Nom », nothing kept for the sign-in" do
    visit invitation_path(@invitation.token)
    without_browser_validation("#invitation-acceptance-form")
    accept_invitation(last_name: "")

    assert_selector "#invitation_last_name_error"
    assert_selector "#invitation_last_name[aria-invalid=true]:focus"

    visit new_session_path
    assert_field "session[contact]", with: ""
  end

  test "FU-53: the invitation page does not scroll sideways at 390 px" do
    with_mobile_viewport do
      visit invitation_path(@invitation.token)

      assert_selector "#invitation-acceptance-form"
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur"
    end
  end

  private

  def accept_invitation(last_name: "Kouassi")
    fill_in "invitation[last_name]", with: last_name
    fill_in "invitation[first_name]", with: "Aya Marie"
    choose I18n.t("genders.female")
    fill_in "invitation[pin]", with: "4821"
    fill_in "invitation[pin_confirmation]", with: "4821"
    click_on I18n.t("identity.invitations.show.submit")
  end

  # The browser would refuse an empty required field before the server: the test wants the server's 422.
  def without_browser_validation(form)
    page.execute_script("document.querySelector(arguments[0]).noValidate = true", form)
  end

  # Counts the submissions of the page, in the capture phase: the autosubmit controller dispatches them synchronously.
  def count_submits
    page.execute_script(<<~JS)
      window.lotASubmits = 0
      document.addEventListener("submit", () => { window.lotASubmits += 1 }, true)
    JS
  end
end
