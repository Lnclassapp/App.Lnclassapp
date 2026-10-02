require "application_system_test_case"

# UDR-0057 R3: a list shows 3 lines, then « Voir plus » reveals the lines already rendered, without a request.
class RevealTest < ApplicationSystemTestCase
  test "« Voir plus » reveals the hidden lines, announces them, then disappears" do
    visit design_path(anchor: "finishes")

    within "#design-reveal" do
      assert_list_capped "ul"
      assert_no_text "Le passé simple"

      assert_no_page_reload { click_on "Voir plus" }

      assert_text "Le passé simple"
      assert_text "La colonisation"
      assert_selector "li", count: 6
      assert_no_button "Voir plus"
      assert_selector "[role=status]", text: "3 lignes de plus affichées.", visible: :all
    end
  end

  test "the sobriety assertions count primary actions and blocks above the fold" do
    visit design_path(anchor: "finishes")

    assert_blocks_above_fold "#design-reveal li", max: 3
    assert_single_primary_action scope: "#design-reveal"
  end
end
