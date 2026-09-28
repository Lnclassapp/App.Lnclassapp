require "application_system_test_case"

# Garde-fou n° 7 : the whole chain (assets, CSP, browser) proven on an empty app.
# TR-01 : the role modals open without a page reload and lead to the right screen.
class HomepageTest < ApplicationSystemTestCase
  test "a visitor opens the homepage in a real browser" do
    visit root_path

    assert_selector "h1"
    assert_title(/ESSAI JETABLE ci-rapide : titre faux/)
  end

  test "the browser loads the application JavaScript under the CSP" do
    visit root_path

    assert page.evaluate_script("typeof window.Turbo !== 'undefined'"), "Turbo n'a pas démarré : JavaScript bloqué ou absent"
  end

  test "a visitor opens the student then the teacher modal, and follows « Rejoindre ma classe »" do
    visit root_path

    assert_no_page_reload do
      within("#hero") { click_on "Je suis élève" }
      within("dialog#role-modal-student-hero[open]") do
        assert_link "Se connecter", href: new_session_path
        assert_link "Rejoindre ma classe", href: new_join_code_path
        find("button[aria-label='Fermer']").click
      end
      assert_no_selector "dialog[open]"

      within("#hero") { click_on "Je suis enseignant" }
      within("dialog#role-modal-teacher-hero[open]") do
        assert_link "Se connecter", href: new_session_path
        assert_link "Créer un compte", href: new_teacher_registration_path
        find("button[aria-label='Fermer']").click
      end
      assert_no_selector "dialog[open]"

      within("#hero") { click_on "Je suis élève" }
      within("dialog#role-modal-student-hero[open]") { click_on "Rejoindre ma classe" }
      assert_current_path new_join_code_path
    end
  end
end
