require "application_system_test_case"

# UDR-0061 (FAQ) : depuis son accueil, l'élève ouvre « Besoin d'aide ? », déplie une question et lit sa réponse, sans JS
# ni rechargement ; à 390 px, la page tient la règle de sobriété (UDR-0057) et ne défile pas en largeur.
class Communication::HelpTest < ApplicationSystemTestCase
  test "from the student home, « Besoin d'aide ? » opens the FAQ and a question unfolds its answer" do
    sign_in_as create_student(classroom: create_classroom)

    click_on "Besoin d'aide ?"
    assert_current_path help_path
    assert_selector "h1", text: "Questions fréquentes"

    within "#help_question_pin" do
      assert_no_text "code de récupération"
      find("summary").click
      assert_text "code de récupération"
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
