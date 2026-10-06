require "test_helper"

# UDR-0075 §3.1, ADR-0081 §4.2: an announcement card takes one of the 10 themes of Lnclass. A theme redefines four tokens
# at the scale of the card, in light and in both dark blocks of UDR-0065 (the phone setting, the switch). The values are
# read from the stylesheet, like test/design/dark_mode_test.rb, and each theme keeps its contrasts in both modes.
class AnnouncementThemesTest < ActiveSupport::TestCase
  STYLESHEET = Rails.root.join("app/assets/stylesheets/application.tailwind.css").read
  THEMES = Entities::Communication::Message::THEMES
  # The two dark blocks of UDR-0065, as test/design/dark_mode_test.rb finds them.
  DARK_MEDIA = "@media screen and (prefers-color-scheme: dark)"
  CHOSEN_MEDIA = "@media screen {\n  :root[data-theme=\"dark\"]"
  # The background, the text (signature and fill-school), the illustration, the strong illustration or the badge.
  TOKENS = %w[brand-soft school brand brand-strong].freeze
  # UDR-0075 §3.1, the table validated by the owner on 2026-10-05: [light, dark], each in the order of TOKENS.
  PALETTE = {
    "ciel" => [ %w[#e5f5ff #1b365d #00a0ff #0070b3], %w[#132c42 #a9c4ee #0070b3 #7fd0ff] ],
    "lagune" => [ %w[#d9f7f3 #0b4a45 #14b8a6 #0f766e], %w[#0f2e2b #99e6dc #0f766e #5eead4] ],
    "menthe" => [ %w[#e3f9e5 #14452a #22c55e #15803d], %w[#13301c #a7e8b8 #15803d #86efac] ],
    "citron" => [ %w[#fff6c7 #4a3b05 #eab308 #a16207], %w[#332a0c #f5e08a #a16207 #fde047] ],
    "mangue" => [ %w[#ffe9d2 #5a2a05 #f97316 #c2410c], %w[#3a220f #fdc897 #c2410c #fdba74] ],
    "corail" => [ %w[#ffe3df #5f1a12 #f2554a #b91c1c], %w[#3d1b18 #fbb4ac #b91c1c #fca5a5] ],
    "hibiscus" => [ %w[#ffe1f3 #5c1642 #ec4899 #be185d], %w[#3d1a30 #f9b4dc #be185d #f9a8d4] ],
    "lavande" => [ %w[#efe5ff #3b1d6e #8b5cf6 #6d28d9], %w[#2a1e45 #d4c2fb #6d28d9 #c4b5fd] ],
    "indigo" => [ %w[#2e3a8c #ffffff #a5b4fc #e0e7ff], %w[#1e2563 #e0e7ff #6366f1 #c7d2fe] ],
    "nuit" => [ %w[#1f2937 #f9fafb #60a5fa #fbbf24], %w[#0b0f17 #e5e7eb #3b82f6 #fbbf24] ]
  }.freeze
  # The card itself: its signature and its audio message are `text-school/NN`, the text at NN % over its background.
  # Read where the card writes them (phase 5), so that this test follows the card instead of a copy of its value.
  CARD = Rails.root.join("app/views/communication/messages/_card.html.erb").read
  TRANSLUCENT_TEXTS = CARD.scan(%r{\btext-school/(\d+)\b}).flatten.uniq.to_h { [ "text-school/#{it}", it.to_i / 100.0 ] }
  SIGNATURE = CARD[%r{<p class="[^"]*\b(text-school/\d+)\b[^"]*">(?:(?!</p>).)*?announcement_signature}m, 1]

  def light = @light ||= themes(STYLESHEET, "")
  def dark = @dark ||= themes(block(DARK_MEDIA, CHOSEN_MEDIA), ':root:not\(\[data-theme="light"\]\) ', indent: "  ")
  def chosen_dark = @chosen_dark ||= themes(block(CHOSEN_MEDIA, nil), ':root\[data-theme="dark"\] ', indent: "  ")

  test "AV-07 — the stylesheet has exactly the 10 themes of Message::THEMES, in light and in both dark blocks, in order" do
    assert_equal 10, THEMES.size
    assert_equal THEMES, light.keys, "clair"
    assert_equal THEMES, dark.keys, "sombre (réglage du téléphone)"
    assert_equal THEMES, chosen_dark.keys, "sombre (interrupteur)"
  end

  test "AV-07 — each theme redefines its four tokens, and only them, with the values of UDR-0075 §3.1" do
    { "clair" => [ light, 0 ], "sombre" => [ dark, 1 ] }.each do |mode, (palette, index)|
      assert_equal PALETTE.keys, palette.keys, mode
      palette.each do |theme, tokens|
        assert_equal TOKENS, tokens.keys, "#{mode} : #{theme}"
        assert_equal PALETTE.fetch(theme)[index], tokens.values, "#{mode} : #{theme}"
      end
    end
  end

  test "AV-07 — the block chosen by the switch carries exactly the values of the system block" do
    assert_equal dark, chosen_dark
  end

  test "AV-07 — « Ciel » is the current look: the tokens of the @theme in light, those of the dark blocks in dark" do
    root = STYLESHEET[/@theme \{(.*?)\n\}/m, 1]
    dark_root = block(DARK_MEDIA, CHOSEN_MEDIA)[/  :root:not\(\[data-theme="light"\]\) \{\n(.*?)\n  \}/m, 1]

    assert_equal tokens(root).values_at(*TOKENS), light.fetch("ciel").values
    assert_equal tokens(dark_root).values_at(*TOKENS), dark.fetch("ciel").values
  end

  test "AV-07 — the light themes come after the tokens, the dark ones inside both dark blocks" do
    theme_end = STYLESHEET.index(/^\}/, STYLESHEET.index("@theme {"))
    first_light = STYLESHEET.index('[data-announcement-theme="ciel"] {')

    assert_operator first_light, :>, theme_end
    assert_operator first_light, :<, STYLESHEET.index(DARK_MEDIA)
  end

  test "the signature of the card is a translucent text of the card, read from the card itself" do
    assert_includes TRANSLUCENT_TEXTS.keys, SIGNATURE
  end

  test "AV-07, AV-08 — text, signature and audio message at the card's opacity, badge or drawing keep their contrast in each theme" do
    failures = { "clair" => light, "sombre" => dark }.flat_map do |mode, palette|
      palette.flat_map do |theme, tokens|
        background, text, _illustration, strong = tokens.values
        translucent = TRANSLUCENT_TEXTS.to_h { |name, alpha| [ name, [ contrast(blend(text, background, alpha), background), 4.5 ] ] }
        { "texte" => [ contrast(text, background), 4.5 ], **translucent,
          "badge (forte)" => [ contrast(strong, background), 3.0 ] }.filter_map do |pair, (ratio, minimum)|
          "#{mode} : #{theme}, #{pair} = #{ratio.round(2)} (< #{minimum})" if ratio < minimum
        end
      end
    end

    assert_empty failures
  end

  test "the contrast helpers follow WCAG 2.x and alpha compositing" do
    assert_in_delta 21.0, contrast("#000000", "#ffffff"), 0.01
    assert_in_delta 1.0, contrast("#0070b3", "#0070b3"), 0.001
    assert_equal "#cccccc", blend("#ffffff", "#000000", 0.8)
    assert_equal "#1b365d", blend("#1b365d", "#e5f5ff", 1.0)
  end

  private

  # The stylesheet from the start marker to the end marker (or to its end).
  def block(start_marker, end_marker)
    start = STYLESHEET.index(start_marker) or flunk "bloc #{start_marker} absent"
    STYLESHEET[start...(end_marker && STYLESHEET.index(end_marker) || STYLESHEET.size)]
  end

  # { "ciel" => { "brand-soft" => "#…", … }, … } in the order of the stylesheet, for the rules
  # `<indent><prefix>[data-announcement-theme="<key>"] { … }`.
  def themes(css, prefix, indent: "")
    rule = /^#{indent}#{prefix}\[data-announcement-theme="([a-z]+)"\] \{\n(.*?)\n#{indent}\}/m
    css.scan(rule).to_h { |theme, body| [ theme, tokens(body) ] }
  end

  def tokens(css) = css.scan(/--color-([a-z-]+):\s*([^;]+);/).to_h

  # WCAG 2.x: relative luminance, then (lighter + 0.05) / (darker + 0.05).
  def contrast(first, second)
    a, b = [ first, second ].map { luminance(it) }.minmax
    (b + 0.05) / (a + 0.05)
  end

  def luminance(hex)
    red, green, blue = channels(hex).map do |value|
      channel = value / 255.0
      channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end
    (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
  end

  # The colour seen when `color` at `alpha` is drawn over `background` (compositing in sRGB, as the browser does).
  def blend(color, background, alpha)
    mixed = channels(color).zip(channels(background)).map { |front, back| ((alpha * front) + ((1 - alpha) * back)).round }
    format("#%02x%02x%02x", *mixed)
  end

  def channels(hex) = hex.delete("#").scan(/../).map { it.to_i(16) }
end
