require "test_helper"

# Golden rule 3 (CLAUDE.md) : French by default, and a missing key fails the test.
class I18nConfigurationTest < ActiveSupport::TestCase
  test "the default locale is French" do
    assert_equal :fr, I18n.default_locale
    assert_equal "janvier", I18n.t("date.month_names")[1]
  end

  test "a missing translation raises instead of rendering a placeholder" do
    assert_raises(I18n::MissingTranslationData) { I18n.t("amorcage.absent_key") }
  end

  test "every locale file, nested per context and screen, is loaded" do
    files = Dir[Rails.root.join("config/locales/**/*.yml")]

    assert_empty files - I18n.load_path.map(&:to_s)
  end
end
