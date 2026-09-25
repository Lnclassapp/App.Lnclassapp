require "test_helper"

# System tests run in a real browser, never under rack_test: rack_test ignores
# CSS visibility, so a green run proves nothing (configuration.md §4.3).
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"]
  end
end
