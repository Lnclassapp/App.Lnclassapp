require "test_helper"

# System tests run in a real browser, never under rack_test: rack_test ignores
# CSS visibility, so a green run proves nothing (configuration.md §4.3).
# CHROME_BIN and CHROMEDRIVER_PATH point at a local Chrome and its driver
# (e.g. /snap/bin/chromium and /snap/bin/chromium.chromedriver); without them,
# selenium-manager finds Chrome as on the GitHub runner. bin/check-chrome
# checks the browser before bin/ci runs these tests.
Selenium::WebDriver::Chrome::Service.driver_path = ENV["CHROMEDRIVER_PATH"] if ENV["CHROMEDRIVER_PATH"].present?

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [ 1400, 1400 ] do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-gpu")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--window-size=1400,1400")
  end

  # The test adapter is shared by every test of the process: an import test that sets perform_enqueued_jobs would leave
  # it on for the next one, which then sees an import « Terminé » instead of « En file d'attente ». Each test starts
  # with jobs queued, not performed; a test that needs them performed sets it in its own setup, which runs after this one.
  setup { ActiveJob::Base.queue_adapter.perform_enqueued_jobs = false }

  MOBILE_VIEWPORT = [ 390, 844 ].freeze

  # The same journey on a phone: the window shrinks for the block, then returns to its size.
  def with_mobile_viewport(size = MOBILE_VIEWPORT)
    window = page.current_window
    original = window.size
    window.resize_to(*size)
    yield
  ensure
    window.resize_to(*original)
  end

  # UDR-0042: the actions of a row or of a header live in its ⋮ menu. Open the menu, then choose the item.
  def click_menu_action(scope, label, **filters)
    within(scope, **filters) do
      find("button[aria-haspopup=menu]").click
      within("[role=menu]") { click_on label }
    end
  end
end
