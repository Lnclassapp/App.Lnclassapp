require "application_system_test_case"

# CA-5 to CA-8 (chantier installation-pwa, UDR-0078 §3.1, amended 2026-10-07): the install pop-up on the home page of a
# phone, in a real Chrome. The browser's
# `beforeinstallprompt` is simulated from the page, with a stubbed `prompt()` and `userChoice`; the iPhone by Safari's user
# agent; the installed app by a `matchMedia` answering `(display-mode: standalone)`, set before the page's scripts run.
# Two sign-ins only (ADR-0069 §9, system budget); the texts of each role are checked on the HTML by
# test/integration/identity/install_banner_test.rb.
class Identity::InstallBannerTest < ApplicationSystemTestCase
  BANNER = "dialog#install_banner".freeze
  STORAGE_KEY = "lnclass.install.later_until".freeze
  IPHONE_SAFARI = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
                  "Version/17.5 Mobile/15E148 Safari/604.1".freeze
  STANDALONE = <<~JS.freeze
    const matchMedia = window.matchMedia.bind(window)
    window.matchMedia = (query) => /display-mode:\\s*standalone/.test(query)
      ? { matches: true, media: query, addEventListener() {}, removeEventListener() {} }
      : matchMedia(query)
    Object.defineProperty(Navigator.prototype, "standalone", { get: () => true })
  JS

  def tb(key) = I18n.t("shared.navigation.install_banner.#{key}")

  test "CA-5, CA-6 — on Android, the student's home opens the pop-up; « Plus tard » or Escape silence it 3 days, « Installer » opens the browser's window" do
    sign_in_as create_student(classroom: create_classroom)
    open_home student_home_path
    offer_install
    assert_no_selector BANNER # écran ≥ lg : jamais de pop-up

    with_mobile_viewport do
      open_home student_home_path
      offer_install
      within(BANNER) do
        assert_selector "#install_banner-title", text: tb("title.student")
        assert_text tb("body.student")
        assert_button tb(:install)
        assert_no_selector "ol"
      end

      # CA-6: « Plus tard », on this phone only: nothing reaches the server, the page stays.
      requests = resource_requests
      page.execute_script("window.samePage = true")
      click_button tb(:later)

      assert_no_selector BANNER
      assert_in_delta 3.days.from_now.to_f * 1000, later_until, 60_000
      assert evaluate_script("window.samePage")
      assert_equal requests, resource_requests

      store_later_until(2.days.from_now)
      open_home student_home_path
      offer_install
      assert_no_selector BANNER

      # Escape (or the cross, or the backdrop) counts as « Plus tard ».
      store_later_until(1.minute.ago)
      open_home student_home_path
      offer_install
      assert_selector BANNER
      find(BANNER).send_keys(:escape)
      assert_no_selector BANNER
      assert_in_delta 3.days.from_now.to_f * 1000, later_until, 60_000

      # The three days are over: the pop-up comes back; « Installer » opens the browser's window, accepted.
      store_later_until(1.minute.ago)
      open_home student_home_path
      offer_install
      within(BANNER) { click_button tb(:install) }

      assert_no_selector BANNER
      assert_equal 1, evaluate_script("window.installPrompts")
      assert_operator later_until, :<, Time.current.to_f * 1000

      # The window closed without installing counts as « Plus tard ».
      open_home student_home_path
      offer_install(outcome: "dismissed")
      within(BANNER) { click_button tb(:install) }

      assert_no_selector BANNER
      assert_in_delta 3.days.from_now.to_f * 1000, later_until, 60_000
    end
  end

  test "CA-7, CA-8 — on Safari iPhone, the teacher sees the two numbered steps; never a banner in the installed app" do
    as_iphone_safari do
      sign_in_as create_teacher(first_name: "Yao")

      with_mobile_viewport do
        open_home teacher_home_path
        within(BANNER) do
          assert_selector "#install_banner-title", text: tb("title.teacher")
          assert_equal [ "1 Touchez Partager", "2 Puis Sur l'écran d'accueil" ], all("ol > li").map { it.text.squish }
          assert_no_button tb(:install)
          assert_button tb(:later)
        end

        in_standalone_display_mode do
          open_home teacher_home_path
          assert_no_selector BANNER
        end
      end
    end

    # CA-8 on Android: the installed app, even if the browser announced the site installable.
    with_mobile_viewport do
      in_standalone_display_mode do
        open_home teacher_home_path
        offer_install
        assert_no_selector BANNER
      end
    end
  end

  private

  # A full load of the page (never the Turbo reload that follows a new session), its install controller connected.
  def open_home(path)
    visit path
    assert_current_path path
    assert_selector "[data-controller=install] #{BANNER}", visible: :all
    page.document.synchronize do
      connected = evaluate_script(<<~JS)
        !!window.Stimulus?.getControllerForElementAndIdentifier(document.querySelector("[data-controller=install]"), "install")
      JS
      raise Capybara::ExpectationNotMet, "le contrôleur install n'est pas encore branché" unless connected
    end
  end

  # The browser announces the site is installable: what Chrome Android fires on its own.
  def offer_install(outcome: "accepted")
    page.execute_script(<<~JS, outcome)
      window.installPrompts = 0
      const event = new Event("beforeinstallprompt", { cancelable: true })
      event.prompt = () => { window.installPrompts++; return Promise.resolve() }
      event.userChoice = Promise.resolve({ outcome: arguments[0], platform: "web" })
      window.dispatchEvent(event)
    JS
  end

  def later_until = evaluate_script("Number(localStorage.getItem('#{STORAGE_KEY}'))")

  def store_later_until(time)
    page.execute_script("localStorage.setItem(arguments[0], arguments[1])", STORAGE_KEY, (time.to_f * 1000).to_i.to_s)
  end

  def resource_requests = evaluate_script("performance.getEntriesByType('resource').length")

  def cdp(command, **params) = page.driver.browser.execute_cdp(command, **params)

  def as_iphone_safari
    original = evaluate_script("navigator.userAgent")
    cdp("Emulation.setUserAgentOverride", userAgent: IPHONE_SAFARI)
    yield
  ensure
    cdp("Emulation.setUserAgentOverride", userAgent: original) if original
  end

  def in_standalone_display_mode
    script = cdp("Page.addScriptToEvaluateOnNewDocument", source: STANDALONE).fetch("identifier")
    yield
  ensure
    cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: script) if script
  end
end
