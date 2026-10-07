require "test_helper"

# UDR-0065, amendement du 2026-10-03 : le choix de l'interrupteur est relu dans le cookie `theme`, « light » ou « dark »
# seulement ; sans choix valable, la page suit le réglage du téléphone.
class ThemeHelperTest < ActionView::TestCase
  test "without a choice, the page follows the phone" do
    assert_nil theme_preference
    assert_equal "light dark", color_scheme_content
  end

  test "the switch's choice is read from the cookie" do
    %w[dark light].each do |theme|
      cookies[:theme] = theme

      assert_equal theme, theme_preference
      assert_equal theme, color_scheme_content
    end
  end

  test "any other value is ignored" do
    cookies[:theme] = "blue"

    assert_nil theme_preference
    assert_equal "light dark", color_scheme_content
  end
end
