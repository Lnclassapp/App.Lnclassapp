require "application_system_test_case"

# Garde-fou n° 7 : the whole chain (assets, CSP, browser) proven on an empty app.
class HomepageTest < ApplicationSystemTestCase
  test "a visitor opens the homepage in a real browser" do
    visit root_path

    assert_selector "h1"
    assert_title(/Lnclass/)
  end

  test "the browser loads the application JavaScript under the CSP" do
    visit root_path

    assert page.evaluate_script("typeof window.Turbo !== 'undefined'"), "Turbo n'a pas démarré : JavaScript bloqué ou absent"
  end
end
