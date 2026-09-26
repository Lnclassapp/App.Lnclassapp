require "application_system_test_case"

# ADR-0049 (amendement du 2026-09-26) : le nonce CSP reste le même pendant toute la session, et la connexion recharge
# la page. Une navigation Turbo Drive garde le document, donc la CSP de sa première page ; avec un nonce neuf à chaque
# requête, les <style> que Trix pose sous le nonce de la balise meta étaient refusés : la barre d'outils perdait son
# habillage et le champ de lien caché interceptait les clics. Parcours : connexion, accueil, « Cours », « Nouveau cours ».
class Shared::CspTurboNavigationTest < ApplicationSystemTestCase
  # The team home belongs to lot B6: until it is merged, a stand-in answers where the sign-in lands, as in
  # test/system/catalog/course_catalog_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true, formats: :html) })
  end

  def t(key, **) = I18n.t(key, **)
  def nonce = page.evaluate_script("document.querySelector('meta[name=csp-nonce]').content")

  test "the rich text editor keeps its styles after sign-in and Turbo navigations, under the strict CSP" do
    create_level(name: "Tle", position: 7)
    create_material(name: "SVT", shortname: "SVT")
    sign_in_as create_team_member
    assert_current_path team_home_path
    first_nonce = nonce
    # Any violation of the Content Security Policy is recorded, to be asserted empty.
    page.execute_script(<<~JS)
      window.cspViolations = []
      document.addEventListener("securitypolicyviolation", (event) => window.cspViolations.push(event.violatedDirective))
    JS

    assert_no_page_reload do
      click_on t("shared.navigation.courses"), match: :first
      assert_current_path courses_path
      click_on t("catalog.courses.index.new_course")
      assert_selector "turbo-frame#modal dialog[open] trix-editor"
    end

    assert_equal first_nonce, nonce, "le nonce change pendant la session"
    assert_equal "block", page.evaluate_script("getComputedStyle(document.querySelector('trix-editor')).display"),
                 "les styles de Trix n'ont pas été appliqués"
    editor = find("trix-editor")
    editor.click
    editor.send_keys("Transcription")
    assert_equal "Transcription", page.evaluate_script("document.querySelector('trix-editor').editor.getDocument().toString().trim()")
    assert_empty page.evaluate_script("window.cspViolations")
  end
end
