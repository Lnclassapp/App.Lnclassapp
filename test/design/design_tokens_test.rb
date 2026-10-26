require "test_helper"

# UDR-0005 — le design system ne s'emprunte que par ses tokens. Ce test lit les sources qui portent des classes
# (vues, helpers, JavaScript) et refuse tout ce qui contournerait la palette, les rayons, les ombres ou l'échelle.
class DesignTokensTest < ActiveSupport::TestCase
  SOURCES = Rails.root.glob("app/{views,helpers,javascript}/**/*.{erb,rb,js}").freeze

  # Échelle d'espacement autorisée (UDR-0005 §3), en unités Tailwind de 0,25 rem.
  SPACING_SCALE = %w[0 0.5 1 1.5 2 2.5 3 4 5 6 8 10 12 14 16 20 24 28 32].freeze
  SPACING_UTILITIES = %w[
    p px py pt pr pb pl ps pe m mx my mt mr mb ml ms me gap gap-x gap-y space-x space-y
    inset inset-x inset-y top right bottom left start end translate-x translate-y scroll-mt scroll-mb scroll-pt scroll-pb
  ].freeze
  DEFAULT_PALETTE = %w[
    slate gray zinc neutral stone red orange amber yellow lime green emerald teal cyan sky blue indigo violet purple
    fuchsia pink rose black
  ].freeze
  COLOR_UTILITIES = %w[bg text border ring outline fill stroke from via to divide decoration accent caret placeholder shadow].freeze

  RULES = {
    "valeur arbitraire `-[…]`" => /[\w:.\/-]*[\w)]-\[[^\]\s]+\]/,
    "propriété arbitraire `[prop:valeur]`" => /(?<![\w\]\[.])\[[a-z-]+:[^\]\s]+\]/,
    "variable CSS arbitraire `-(--…)`" => /-\(--[\w-]+\)/,
    "couleur hexadécimale" => /(?<![\w-])#(?:\h{8}|\h{6}|\h{3,4})\b/,
    "attribut `style`" => /\bstyle\s*[=:]\s*["'{]/,
    "variante `dark:` (le mode sombre passe par les tokens, UDR-0065)" => /(?<![\w-])dark:/,
    "couleur de la palette par défaut" =>
      /(?<![\w-])(?:#{COLOR_UTILITIES.join('|')})-(?:#{DEFAULT_PALETTE.join('|')})(?:-\d+)?(?![\w-])/,
    "rayon hors tokens" => /(?<![\w-])rounded(?:-[trblse]{1,2})?-(?:xs|md|lg|xl|2xl|3xl|4xl)(?![\w-])/,
    "ombre hors tokens" => /(?<![\w-])shadow-(?:2xs|xs|sm|md|lg|xl|2xl|inner)(?![\w-])/,
    "police hors tokens" => /(?<![\w-])font-serif(?![\w-])/
  }.freeze

  SPACING = /(?<![\w-])-?(?:#{SPACING_UTILITIES.join('|')})-(\d+(?:\.\d+)?)(?![\w.\/-])/

  # UDR-0086 §3.5 : le palier de 700 px des pages élève redessinées (UDR-0084, 0085, 0086) s'écrit `min-[700px]:`, sans
  # token de point de rupture. Seule cette variante est admise ; toute autre valeur entre crochets reste refusée.
  SANCTIONED_VARIANT = /(?<![\w-])min-\[700px\]:/

  test "the sources exist" do
    assert_operator SOURCES.size, :>, 20
  end

  # UDR palette froide §3.1 (CA-F1) : page blanche, gris bleutés, une seule police.
  STYLESHEET = Rails.root.join("app/assets/stylesheets/application.tailwind.css").read
  COLD_PALETTE = {
    "ink" => "#1f2128", "mute" => "#5f6470", "line" => "#e3eef7", "line-strong" => "#c3d8e8", "mist" => "#f4f8fb",
    "paper" => "#ffffff", "warning" => "#8a4a00", "warning-dot" => "#f08c00", "band-ink" => "#0b2a40",
    "brand" => "#00a0ff", "brand-soft" => "#e5f5ff", "brand-strong" => "#0070b3", "teacher" => "#ff8a00",
    "success" => "#18723f", "warning-soft" => "#fff1dc"
  }.freeze
  COLD_PALETTE_DARK = { "line-strong" => "#3a4655", "warning-dot" => "#ffa94d", "band-ink" => "#ffffff" }.freeze

  test "the theme carries the cold palette of the pilot" do
    theme = STYLESHEET[/@theme \{(.*?)\n\}/m, 1]

    COLD_PALETTE.each { |token, value| assert_includes theme, "--color-#{token}: #{value};", token }
    assert_includes theme, "--text-meta: 0.8125rem;"
  end

  test "the new tokens have their dark value in both dark blocks" do
    dark_blocks = STYLESHEET.split("@media screen").drop(1)

    assert_operator dark_blocks.size, :>=, 2
    COLD_PALETTE_DARK.each do |token, value|
      assert_equal 2, STYLESHEET.scan("--color-#{token}: #{value};").size, "#{token} : les deux blocs sombres"
    end
  end

  test "a single font: titles in DM Sans, Bricolage Grotesque is no longer served" do
    assert_includes STYLESHEET, '--font-display: "DM Sans", ui-sans-serif, system-ui, sans-serif;'
    assert_no_match(/Bricolage/i, STYLESHEET)
    assert_empty Rails.root.glob("app/assets/fonts/*bricolage*")
  end

  RULES.each do |name, pattern|
    test "no #{name} in views, helpers or JavaScript" do
      offences = scan(pattern)

      assert_empty offences, "#{name} — utilisez un token du @theme (UDR-0005) :\n#{offences.join("\n")}"
    end
  end

  test "spacing stays on the allowed scale" do
    offences = scan(SPACING) { |match| !SPACING_SCALE.include?(match[1]) }

    assert_empty offences, "espacement hors échelle (#{SPACING_SCALE.join(', ')}) :\n#{offences.join("\n")}"
  end

  # UDR palette froide §3.2 : le texte ne dépasse pas `font-medium`. Exception écrite : le titre gras de la page d'accueil.
  FORBIDDEN_WEIGHT = /(?<![\w-])font-(?:semibold|bold|extrabold|black)(?![\w-])/
  WEIGHT_SOURCES = Rails.root.glob("app/{views,helpers}/**/*.{erb,rb}").reject { |path| path.to_s.include?("app/views/homepage/") }.freeze

  test "no text heavier than font-medium outside the homepage" do
    offences = WEIGHT_SOURCES.flat_map do |path|
      path.each_line.with_index(1).filter_map do |line, number|
        "#{path.relative_path_from(Rails.root)}:#{number}" if line.match?(FORBIDDEN_WEIGHT)
      end
    end

    assert_empty offences, "graisse > 500 interdite (UDR palette froide §3.2), utilisez font-medium :\n#{offences.join("\n")}"
    %w[font-bold md:font-semibold font-bold! font-black].each { |s| assert_match FORBIDDEN_WEIGHT, s }
    %w[font-medium font-normal font-boldly].each { |s| assert_no_match FORBIDDEN_WEIGHT, s }
  end

  test "the patterns catch what they must" do
    {
      "valeur arbitraire `-[…]`" => %w[w-[26rem] md:grid-cols-[1fr_1.4fr] data-[open]:block],
      "propriété arbitraire `[prop:valeur]`" => [ 'class="[scrollbar-width:none]"' ],
      "couleur hexadécimale" => %w[#fff #00a0ff bg-[#add] color:#add],
      "couleur de la palette par défaut" => %w[bg-slate-50 text-blue-600 hover:border-gray-200],
      "rayon hors tokens" => %w[rounded-xl rounded-t-2xl],
      "ombre hors tokens" => %w[shadow-lg]
    }.each do |rule, samples|
      samples.each { |sample| assert_match RULES.fetch(rule), sample, "#{rule} devrait refuser #{sample}" }
    end
    %w[rounded-card shadow-pop bg-brand-soft role[:accent] href="#pour-qui" text-ink/60 teams--nested-form#add].each do |sample|
      RULES.each_value { |pattern| assert_no_match pattern, sample }
    end
    assert_no_match RULES.fetch("valeur arbitraire `-[…]`"), "min-[700px]:grid-cols-6".gsub(SANCTIONED_VARIANT, "")
    assert_match RULES.fetch("valeur arbitraire `-[…]`"), "min-[701px]:grid-cols-6".gsub(SANCTIONED_VARIANT, "")
    assert_equal "7", SPACING.match("p-7")[1]
    assert_nil SPACING.match("size-7")
  end

  private

  def scan(pattern)
    SOURCES.flat_map do |path|
      path.each_line.with_index(1).flat_map do |line, number|
        line.gsub(SANCTIONED_VARIANT, "").to_enum(:scan, pattern).map { Regexp.last_match }
            .select { |match| !block_given? || yield(match) }
            .map { |match| "#{path.relative_path_from(Rails.root)}:#{number} #{match[0]}" }
      end
    end
  end
end
