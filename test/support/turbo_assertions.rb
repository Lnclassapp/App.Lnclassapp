# Hotwire proofs for system tests (UDR-0006): no full page reload, a screen opened in the modal
# frame, a toast on screen.
module TurboAssertions
  ActionDispatch::SystemTestCase.include(self)

  # A marker set on window survives a Turbo render and dies with a real reload.
  def assert_no_page_reload
    marker = SecureRandom.hex(8)
    page.execute_script("window.lnclassReloadMarker = arguments[0]", marker)
    yield
    assert_turbo_idle
    assert_equal marker, page.evaluate_script("window.lnclassReloadMarker"), "la page a été rechargée"
  end

  # For a lot whose opening button lives in the screen of another lot.
  def open_in_modal(path)
    page.execute_script("Turbo.visit(arguments[0], { frame: 'modal' })", path)
    assert_selector "turbo-frame#modal dialog[open]"
  end

  def assert_toast(text)
    assert_selector "#toasts", text:
  end

  # Un toast reste 5 s (ou jusqu'à sa fermeture pour une erreur) en bas à droite et peut recouvrir le bouton du clic
  # suivant (ElementClickInterceptedError en suite parallèle) : on le ferme par son vrai bouton et on attend son départ.
  def dismiss_toasts
    all("#toasts button[data-action='toast#dismiss']").each do |button|
      button.click
    rescue Selenium::WebDriver::Error::StaleElementReferenceError, Selenium::WebDriver::Error::ElementClickInterceptedError
      nil # le toast s'est fermé seul entre la recherche et le clic : il a déjà quitté la page
    end
    assert_no_selector "#toasts [data-controller=toast]"
  end

  private

  # Turbo marks the document and the submitted form aria-busy while a request runs.
  def assert_turbo_idle
    assert_no_selector "html[aria-busy=true]", visible: :all
    assert_no_selector "form[aria-busy=true]", visible: :all
  end
end
