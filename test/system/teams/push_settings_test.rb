require "application_system_test_case"

# UDR XXXX §3.3, §3.5 : à 390 px, un admin coche « Devoir à rendre » sans recharger la page, lit « Automatique depuis le … »
# et retrouve la ligne dans l'historique ; un compte `content` voit la case désactivée.
class Teams::PushSettingsTest < ApplicationSystemTestCase
  test "an admin checks « Devoir à rendre » on a phone without a reload and finds it in the history" do
    admin = create_team_member(first_name: "Awa", last_name: "Koné")
    sign_in_as admin

    with_mobile_viewport do
      visit teams_push_settings_path
      assert_selector "h1", text: "Notifications"
      assert_no_selector "#push_motive_assignment_due input:checked", visible: :all

      assert_no_page_reload do
        find("#push_motive_assignment_due label").click

        assert_toast "Réglage enregistré."
        within("#push_motive_assignment_due") { assert_text(/Automatique depuis le .*, par Awa K\./) }
        within("#push_history_list") { assert_text "Awa K. a rendu Devoir à rendre demain automatique" }
      end
      assert_selector "#push_motive_assignment_due input:checked", visible: :all
    end
    assert Orm::Communication::PushMotiveSetting.find_by!(motive: "assignment_due").automatic
  end

  test "a content member sees the switch disabled and the reason" do
    sign_in_as create_team_member(team_role: "content")

    visit teams_push_settings_path

    assert_selector "#push_motive_assignment_due input[disabled]", visible: :all
    within("#push_motive_assignment_due") { assert_text "Seul un admin peut changer ce réglage." }
  end
end
