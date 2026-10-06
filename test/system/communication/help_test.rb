require "application_system_test_case"

# UDR-0061 (FAQ ; amendement du 2026-10-06 : shell une fois connecté) : depuis son accueil, l'élève ouvre « Besoin d'aide ? », puis « Questions fréquentes » dans la carte d'aide,
# déplie une question et lit sa réponse, sans JS ni rechargement ; à 390 px, la page tient la règle de sobriété (UDR-0057) et ne défile pas en largeur.
class Communication::HelpTest < ApplicationSystemTestCase
  test "from the student home, « Besoin d'aide ? » opens the FAQ and a question unfolds its answer" do
    sign_in_as create_student(classroom: create_classroom)

    click_on "Besoin d'aide ?"
    within("dialog#help-sheet") { click_on "Questions fréquentes" }
    assert_current_path help_path
    assert_selector "h1", text: "Questions fréquentes"

    within "#help_question_pin" do
      assert_no_text "code de récupération"
      find("summary").click
      assert_text "code de récupération"
    end
  end

  # UDR-0061, amendment of 2026-10-06: signed in, the student keeps the shell and its bottom bar on the FAQ.
  test "on a phone, a signed-in student reads the FAQ in the shell, the bottom bar still there" do
    sign_in_as create_student(classroom: create_classroom)

    with_mobile_viewport do
      visit help_path

      assert_selector "#main h1", text: "Questions fréquentes"
      assert_selector "nav a", text: "Cours"
      assert_link "Accueil", href: student_home_path
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end

  test "on a phone, the FAQ passes the sobriety rule without horizontal scrolling" do
    with_mobile_viewport do
      visit help_path

      assert_single_primary_action scope: "main"
      assert_blocks_above_fold "main > div > *"
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end
end
