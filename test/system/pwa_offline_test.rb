require "application_system_test_case"

# installation-pwa, Lot A (ADR-0082 §4.2, UDR-0078 §3.2). CA-3 and CA-4 in a real Chrome: the page registers the service
# worker at the scope "/", which takes control; with the network cut, a link followed and the home seen before both give
# the static « Pas de connexion » page, never the student's own page; the worker's storage holds the three offline files
# only; with the network back, « Réessayer » reloads the page that was asked for. One journey, one sign-in (ADR-0069 §9).
class PwaOfflineTest < ApplicationSystemTestCase
  OFFLINE_FILES = %w[/icon-192.png /offline.css /offline.html].freeze

  test "CA-3, CA-4 — without network a signed-in student sees « Pas de connexion », never their page, then « Réessayer » brings it back" do
    student = create_student(classroom: create_classroom, first_name: "Aïcha", last_name: "Bamba")
    sign_in_as student
    assert_text I18n.t("classroom.student_homes.show.greeting", name: "Aïcha")
    home = page.current_path

    assert_equal "#{Capybara.current_session.server.base_url}/", service_worker_scope
    assert_controlled_by_the_service_worker

    with_network_cut do
      # CA-3: Turbo's request fails, Turbo reloads the page, the service worker answers the navigation.
      within("aside nav:not(#sidebar_secondary)") { click_link I18n.t("shared.navigation.courses") }
      assert_offline_page_without(student)
      assert_current_path courses_path

      # CA-4: the home seen before the cut is not kept on the phone.
      visit home
      assert_offline_page_without(student)
      assert_equal({ "lnclass-offline-v1" => OFFLINE_FILES }, cached_paths)
    end

    click_link "Réessayer"
    assert_text I18n.t("classroom.student_homes.show.greeting", name: "Aïcha")
    assert_current_path home
  end

  private

  def assert_offline_page_without(student)
    assert_selector "h1", text: "Pas de connexion"
    assert_link "Réessayer"
    assert_title "Pas de connexion · Lnclass"
    [ student.first_name, student.last_name, student.contact ].each { assert_no_text it, wait: 0 }
  end

  def service_worker_scope
    page.evaluate_async_script("navigator.serviceWorker.ready.then((registration) => arguments[0](registration.scope))")
  end

  # clients.claim() at activation: the page that registered the worker is controlled without a reload.
  def assert_controlled_by_the_service_worker
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "le programme ne contrôle pas la page" unless page.evaluate_script("!!navigator.serviceWorker.controller")
    end
  end

  # Cache name => sorted paths of what it holds, as the page can read it.
  def cached_paths
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      caches.keys().then((names) => Promise.all(names.map((name) =>
        caches.open(name).then((cache) => cache.keys()).then((requests) => [name, requests.map((r) => new URL(r.url).pathname).sort()])
      ))).then((entries) => done(Object.fromEntries(entries)))
    JS
  end

  # The network is cut for the page and for the service worker: Chrome emulates a network per DevTools target, and the
  # worker's own fetch() is not the page's. Chromedriver speaks to the page only, so the worker is reached through
  # Target.sendMessageToTarget (a session without flatten mode), whose answer is not needed.
  def with_network_cut
    browser = page.driver.browser
    workers = browser.execute_cdp("Target.getTargets")["targetInfos"].select { it["type"] == "service_worker" }
    sessions = workers.map { browser.execute_cdp("Target.attachToTarget", targetId: it["targetId"], flatten: false)["sessionId"] }
    assert_equal 1, sessions.size, "un programme d'arrière-plan actif"
    emulate_network(browser, sessions, offline: true)
    yield
  ensure
    emulate_network(browser, sessions, offline: false)
    sessions.each { browser.execute_cdp("Target.detachFromTarget", sessionId: it) }
  end

  def emulate_network(browser, sessions, offline:)
    conditions = { offline:, latency: 0, downloadThroughput: -1, uploadThroughput: -1 }
    browser.execute_cdp("Network.enable")
    browser.execute_cdp("Network.emulateNetworkConditions", **conditions)
    sessions.each do |session|
      [ "Network.enable", "Network.emulateNetworkConditions" ].each.with_index(1) do |method, id|
        message = { id:, method:, params: method.end_with?("Conditions") ? conditions : {} }
        browser.execute_cdp("Target.sendMessageToTarget", sessionId: session, message: message.to_json)
      end
    end
  end
end
