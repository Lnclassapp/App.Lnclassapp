require "test_helper"

# UDR-0065 — le mode sombre passe par les tokens : chaque couleur du @theme a sa valeur sombre, dans un bloc réservé
# à l'écran, et chaque paire texte/fond que les composants emploient garde un contraste lisible dans les deux modes.
class DarkModeTest < ActiveSupport::TestCase
  STYLESHEET = Rails.root.join("app/assets/stylesheets/application.tailwind.css").read
  DARK_MEDIA = "@media screen and (prefers-color-scheme: dark)"
  CHOSEN_MEDIA = "@media screen {\n  :root[data-theme=\"dark\"]"

  # Paires des composants (ComponentsHelper : boutons, badges, toasts ; pages : texte sur surfaces), [texte, fond, minimum].
  TEXT_PAIRS = [
    %w[ink paper], %w[ink white], %w[ink mist], %w[mute white], %w[mute paper], %w[mute mist],
    %w[white ink], %w[ink brand], %w[ink brand-soft], %w[brand-strong paper], %w[brand-strong white], %w[brand-strong brand-soft],
    %w[success success-soft], %w[warning warning-soft], %w[error error-soft], %w[success white], %w[warning white], %w[error white],
    %w[white error], %w[white team], %w[white school], %w[ink teacher], %w[ink gold], %w[school white], %w[team white]
  ].map { [ *it, 4.5 ] }.freeze
  # Le contour de focus (`outline-brand`) se voit sur les surfaces sombres. En clair, il est à 2,7 : constat hors chantier.
  DARK_ONLY_PAIRS = [ [ "brand", "paper", 3.0 ], [ "brand", "white", 3.0 ] ].freeze
  # UDR-0074 §3.7 : les pastilles de la direction se lisent sur leur anneau, de la couleur de la carte (3:1, élément graphique).
  # Constat du challenger (phase 5, O5) : le jaune #f2b705 n'y avait que 1,82.
  SIGNAL_PAIRS = %w[signal-green signal-yellow signal-red].map { [ it, "white", 3.0 ] }.freeze

  def light = @light ||= tokens(STYLESHEET[/@theme \{(.*?)\n\}/m, 1])
  def dark = @dark ||= tokens(dark_block)
  def chosen_dark = tokens(chosen_block)

  test "the dark block applies to the screen only, so a printed page stays light" do
    assert_includes STYLESHEET, DARK_MEDIA
    assert_equal 1, STYLESHEET.scan("prefers-color-scheme").size, "un seul bloc sombre"
    assert_match(/color-scheme: dark;/, dark_block)
    assert_includes dark_block, ":root:not([data-theme=\"light\"]) {", "un choix « clair » l'emporte sur un téléphone sombre"
  end

  # Amendement du 2026-10-03 : l'interrupteur pose data-theme="dark" ; ce bloc-là porte exactement les mêmes valeurs.
  test "the block chosen by the switch carries exactly the values of the system block" do
    assert_includes STYLESHEET, CHOSEN_MEDIA
    assert_equal dark, chosen_dark
    assert_equal dark_block[/  :root[^\n]*\{\n(.*?)\n  \}/m, 1], chosen_block[/  :root[^\n]*\{\n(.*?)\n  \}/m, 1], "ombres et color-scheme compris"
    assert_match(/:root\[data-theme="dark"\] dialog::backdrop \{\s*background-color: rgb\(0 0 0/, chosen_block)
  end

  test "every literal colour of the theme has its dark value, and nothing else is redefined" do
    literal = light.reject { |_, value| value.start_with?("var(") }

    assert_equal literal.keys.sort, dark.keys.sort, "chaque --color-* littéral du @theme a sa valeur sombre (UDR-0065)"
    dark.each_value { |value| assert_match(/\A#\h{6}\z/, value) }
  end

  # UDR-0072 §3.1 : les quatre couleurs de la compréhension, pastilles et barres seulement (jamais un texte).
  test "the four comprehension tokens exist in the theme and in both dark blocks" do
    comprehension = %w[struggling struggling-soft fragile fragile-soft]

    assert_equal %w[#c8322b #fdecea #e0a800 #fff8d2], light.values_at(*comprehension)
    assert_equal %w[#ff7b72 #3d2023 #facc15 #3a3214], dark.values_at(*comprehension)
    assert_equal dark.values_at(*comprehension), chosen_dark.values_at(*comprehension)
  end

  test "the shadows are redefined for dark surfaces, and the modal backdrop stays a dark veil" do
    %w[--shadow-card --shadow-lift --shadow-pop].each { |shadow| assert_match(/#{shadow}: [^;]*rgb\(0 0 0/, dark_block) }
    assert_match(/dialog::backdrop \{\s*background-color: rgb\(0 0 0/, dark_block)
  end

  test "every text and background pair of the components stays readable, in light and in dark" do
    failures = { "clair" => [ light, TEXT_PAIRS + SIGNAL_PAIRS ],
                 "sombre" => [ dark, TEXT_PAIRS + DARK_ONLY_PAIRS + SIGNAL_PAIRS ] }.flat_map do |mode, (palette, pairs)|
      pairs.filter_map do |text, background, minimum|
        ratio = contrast(palette.fetch(text), palette.fetch(background))
        "#{mode} : #{text} sur #{background} = #{ratio.round(2)} (< #{minimum})" if ratio < minimum
      end
    end

    assert_empty failures
  end

  test "the layout tells the browser both schemes, before the stylesheet arrives" do
    layout = Rails.root.join("app/views/layouts/application.html.erb").read

    assert_includes layout, '<meta name="color-scheme" content="<%= color_scheme_content %>">'
    assert_includes layout, "tag.attributes(data: { theme: theme_preference })"
  end

  private

  def dark_block
    start = STYLESHEET.index(DARK_MEDIA) or flunk "bloc #{DARK_MEDIA} absent"
    STYLESHEET[start...(STYLESHEET.index(CHOSEN_MEDIA) || STYLESHEET.size)]
  end

  def chosen_block
    start = STYLESHEET.index(CHOSEN_MEDIA) or flunk "bloc du choix sombre absent"
    STYLESHEET[start..]
  end

  def tokens(css) = css.scan(/--color-([a-z-]+):\s*([^;]+);/).to_h.reject { |name, _| name == "*" }

  # WCAG 2.x : luminance relative, puis (clair + 0,05) / (sombre + 0,05).
  def contrast(first, second)
    a, b = [ first, second ].map { luminance(it) }.minmax
    (b + 0.05) / (a + 0.05)
  end

  def luminance(hex)
    red, green, blue = hex.delete("#").scan(/../).map do |pair|
      channel = pair.to_i(16) / 255.0
      channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end
    (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
  end
end
