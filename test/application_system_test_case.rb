require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # CHROME_BIN désigne un Chrome local quand Selenium Manager ne peut pas en télécharger un (poste hors ligne).
  # Le pilote correspondant se désigne, lui, par SE_CHROMEDRIVER, que Selenium lit directement.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"]
  end
end
