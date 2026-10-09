require "application_system_test_case"

# Finitions UX, Lot H (UDR-0054 §3.1, §3.2, §3.3, §3.5): « Mon profil » and the account pages.
# FU-05 (a modal opened by its URL has its title), FU-10 (« Mon profil » goes back to « Accueil »),
# FU-27 (the PIN recovery code, made to be dictated, is never copied).
module Finitions; end

class Finitions::AccountPagesTest < ApplicationSystemTestCase
  PROFILE_MODALS = {
    "profile_name_last_name" => [ :edit_profile_name_path, "Modifier mon nom" ],
    "contact_change_current_pin" => [ :edit_profile_contact_path, "Changer mon numéro" ],
    "pin_change_current_pin" => [ :edit_profile_pin_path, "Changer mon code secret" ],
    "profile_photo_photo" => [ :edit_profile_photo_path, "Ma photo" ]
  }.freeze

  setup do
    @classroom = create_classroom(name: "Tle D 1")
    @student = create_student(classroom: @classroom, first_name: "Aya", last_name: "Koné")
  end

  # FU-05
  test "the name modal opened by its URL names the tab" do
    sign_in_as @student
    visit edit_profile_name_path

    assert_selector "dialog#profile-name-modal[open]"
    assert_equal "Modifier mon nom · Élève · Lnclass", page.title
  end

  # FU-10
  test "« Mon profil » has its back link « Accueil », the first link of the main content" do
    sign_in_as @student
    visit profile_path

    assert_equal "Mon profil · Élève · Lnclass", page.title
    back = first("main a")
    assert_equal "Accueil", back.text
    assert_equal student_home_path, URI(back[:href]).path
    assert_selector "main nav[aria-label='#{I18n.t('components.back_link.label')}'] + div h1", text: "Mon profil"

    back.click
    assert_current_path student_home_path
  end

  test "the back link of « Mon profil » leads to the home of each role" do
    sign_in_as create_teacher(school: @classroom.school, classrooms: [ @classroom ])
    visit profile_path

    assert_equal teacher_home_path, URI(first("main a")[:href]).path
    assert_equal "Accueil", first("main a").text
  end

  test "each profile modal targets its first field, without an autofocus attribute, and names the tab while open" do
    sign_in_as @student
    visit profile_path
    title = page.title

    PROFILE_MODALS.each do |field, (route, heading)|
      open_in_modal public_send(route)

      within("turbo-frame#modal dialog[open]") { assert_selector "h2", text: heading }
      assert_no_selector "[autofocus]", visible: :all
      assert_equal field, evaluate_script("document.activeElement.id")
      assert_title "#{heading} · Élève · Lnclass"

      within("turbo-frame#modal dialog[open]") { click_on "Annuler" }
      assert_no_selector "turbo-frame#modal dialog[open]"
      # Le titre revient à la fermeture de la <dialog>, un instant après sa disparition : assert_title attend.
      assert_title title
    end
  end

  # ADR-0085 §4.3 : l'écran d'attente n'est plus la destination d'un élève ; il reste celle d'un enseignant sans établissement.
  test "the pending account page has a composed title" do
    sign_in_as create_user(role: "teacher", first_name: "Awa", last_name: "Traoré")

    assert_selector "#pending_account"
    assert_equal "Compte en attente · Enseignant · Lnclass", page.title
  end

  # FU-27
  test "the PIN recovery code modal offers no copy, and names the tab" do
    teacher = create_teacher(school: @classroom.school, classrooms: [ @classroom ])
    sign_in_as teacher
    visit classroom_path(@classroom.public_id)

    click_menu_action("[id='student_#{@student.public_id}']", I18n.t("classroom.classrooms.roster.issue_code"))

    within "turbo-frame#modal dialog#pin-recovery-code-modal[open]" do
      assert_match(/\A\d{4} \d{4}\z/, find("#pin-recovery-code").text)
      assert_no_selector "[data-controller~=clipboard]", visible: :all
      assert_no_button(/Copier/)
      assert_no_text "Copier"
    end
    assert_equal "Code de récupération · Enseignant · Lnclass", page.title
  end
end
