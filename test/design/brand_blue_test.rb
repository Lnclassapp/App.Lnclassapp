require "test_helper"

# UDR bleu unique (amende UDR-0136, porteur 2026-11-13) : le bleu roi du logo, #0861E1, est le seul bleu de marque de
# Lnclass, dans l'application, le mode sombre, la PWA, les pages statiques et les apps Android. Un fond bleu porte un
# texte blanc (`on-brand`), dans les deux modes ; `brand-strong` n'est plus qu'un texte ou une icône.
class BrandBlueTest < ActiveSupport::TestCase
  BLUE = "#0861e1".freeze
  STYLESHEET = Rails.root.join("app/assets/stylesheets/application.tailwind.css").read
  DARK_MEDIA = "@media screen and (prefers-color-scheme: dark)"
  CHOSEN_MEDIA = "@media screen {\n  :root[data-theme=\"dark\"]"
  # Les bleus remplacés : l'ancien bleu ciel, ses dérivés clair et sombre, et le 4e bleu de l'icône.
  RETIRED = %w[#00a0ff #0070b3 #e5f5ff #7fd0ff #132c42 #1e6bae #0f6fde].freeze
  BRAND_FILES = %w[
    app/assets/stylesheets/application.tailwind.css config/application.rb
    public/400.html public/404.html public/422.html public/500.html public/offline.html public/offline.css
    app/assets/images/lnclass/icon.svg app/assets/images/lnclass/logo-lnclass.svg
    android/shell/src/main/res/values/colors.xml android/student/src/main/res/values/colors.xml
    android/student/src/main/res/values/ic_launcher_background.xml
  ].freeze
  SOURCES = Rails.root.glob("app/{views,helpers,javascript}/**/*.{erb,rb,js}").freeze
  # La page /design montre chaque token, `brand-strong` compris : seule exception au fond `brand-strong`.
  SWATCHES = "app/views/design/index.html.erb".freeze

  def root = tokens(STYLESHEET[/@theme \{(.*?)\n\}/m, 1])
  def dark_root(start, finish) = tokens(block(start, finish)[/  :root[^\n]*\{\n(.*?)\n  \}/m, 1])

  test "light: brand and brand-strong are the royal blue, brand-soft its light tint, white text on it" do
    assert_equal({ "brand" => BLUE, "brand-strong" => BLUE, "brand-soft" => "#e7f0fd", "on-brand" => "#ffffff" },
                 root.slice("brand", "brand-strong", "brand-soft", "on-brand"))
  end

  test "dark: the same blue background with white text, brand-strong lightened for text, brand-soft deepened" do
    expected = { "brand" => BLUE, "brand-strong" => "#8bb8f9", "brand-soft" => "#122949", "on-brand" => "#ffffff" }

    assert_equal expected, dark_root(DARK_MEDIA, CHOSEN_MEDIA).slice(*expected.keys), "réglage du téléphone"
    assert_equal expected, dark_root(CHOSEN_MEDIA, nil).slice(*expected.keys), "interrupteur"
  end

  test "white on the blue is AA in both modes (5.52:1), and the blue mark is visible on every surface" do
    assert_in_delta 5.52, contrast("#ffffff", BLUE), 0.01
    { "papier clair" => "#ffffff", "papier sombre" => "#0f1218", "carte sombre" => "#171c24" }.each do |name, surface|
      assert_operator contrast(BLUE, surface), :>=, 3.0, name
    end
  end

  test "no retired blue is left in the brand files, and the installed app takes the royal blue" do
    offences = BRAND_FILES.flat_map do |file|
      text = Rails.root.join(file).read.downcase
      RETIRED.select { text.include?(it) }.map { "#{file} : #{it}" }
    end

    assert_empty offences
    assert_equal BLUE, Rails.configuration.x.pwa[:theme_color]
    assert_includes Rails.root.join("android/student/src/main/res/values/colors.xml").read, "#0861E1"
  end

  test "no blue background in brand-strong: the blue background is brand" do
    offences = scan(/(?<![\w-])(?:[\w-]+:)*bg-brand-strong(?![\w-])/).reject { it.start_with?("#{SWATCHES}:") }

    assert_empty offences, "fond `brand` (UDR bleu unique) :\n#{offences.join("\n")}"
  end

  test "a blue background carries on-brand text, never text-white (dark in dark mode) nor text-ink" do
    offences = SOURCES.flat_map do |path|
      path.read.scan(/"([^"\n]*)"/).flatten.filter_map do |classes|
        background = classes[/(?:\A|\s)((?:[\w-]+:)*)bg-brand(?![\w-])/, 1] or next
        "#{path.relative_path_from(Rails.root)} : « #{classes} »" if classes.match?(/(?:\A|\s)#{Regexp.escape(background)}text-(?:white|ink)(?![\w-])/)
      end
    end

    assert_empty offences
  end

  test "a single blue button: the brand variant is gone" do
    assert_empty scan(/ui-button-brand|variant: :brand\b/)
    assert_no_match(/ui-button-brand/, STYLESHEET)
  end

  private

  def scan(pattern)
    SOURCES.flat_map do |path|
      path.each_line.with_index(1).filter_map do |line, number|
        "#{path.relative_path_from(Rails.root)}:#{number}" if line.match?(pattern)
      end
    end
  end

  def block(start_marker, end_marker)
    start = STYLESHEET.index(start_marker) or flunk "bloc #{start_marker} absent"
    STYLESHEET[start...(end_marker && STYLESHEET.index(end_marker) || STYLESHEET.size)]
  end

  def tokens(css) = css.scan(/--color-([a-z-]+):\s*([^;]+);/).to_h

  def contrast(first, second)
    a, b = [ first, second ].map { luminance(it) }.minmax
    (b + 0.05) / (a + 0.05)
  end

  def luminance(hex)
    hex.delete("#").scan(/../).map { it.to_i(16) / 255.0 }
       .map { it <= 0.03928 ? it / 12.92 : ((it + 0.055) / 1.055)**2.4 }
       .then { 0.2126 * it[0] + 0.7152 * it[1] + 0.0722 * it[2] }
  end
end
