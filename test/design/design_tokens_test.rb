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

  # UDR-XXXX (contenu-en-blocs, #318) : l'écran de la fiche de cours reprend les maquettes (Seyès, Kalam, Source Serif 4,
  # graisse 700) dans un habillage à part. L'exception ne vaut que pour ces trois endroits et seulement pour les règles
  # « une seule police », « palette froide » et « graisse 500 » : couleurs hexadécimales, attribut `style`, valeurs
  # arbitraires, palette par défaut, rayons, ombres et échelle d'espacement restent refusés partout, ces dossiers compris.
  SHEET_EXCEPTION = %r{\A(?:app/views/catalog/course_sheets/|app/javascript/controllers/course_sheet/|app/assets/stylesheets/course_sheet(?:/|\.css\z))}
  SHEET_FONTS = /Kalam|Source Serif/i

  def self.sheet_exception?(relative_path) = SHEET_EXCEPTION.match?(relative_path.to_s)

  def relative(path) = path.relative_path_from(Rails.root).to_s

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

  SHEET_EXEMPT_RULES = [ "police hors tokens" ].freeze

  RULES.each do |name, pattern|
    test "no #{name} in views, helpers or JavaScript" do
      offences = scan(pattern, skip_sheet: SHEET_EXEMPT_RULES.include?(name))

      assert_empty offences, "#{name} — utilisez un token du @theme (UDR-0005) :\n#{offences.join("\n")}"
    end
  end

  test "spacing stays on the allowed scale" do
    offences = scan(SPACING) { |match| !SPACING_SCALE.include?(match[1]) }

    assert_empty offences, "espacement hors échelle (#{SPACING_SCALE.join(', ')}) :\n#{offences.join("\n")}"
  end

  # UDR palette froide §3.2 : le texte ne dépasse pas `font-medium`. Exception écrite : le titre gras de la page d'accueil.
  FORBIDDEN_WEIGHT = /(?<![\w-])font-(?:semibold|bold|extrabold|black)(?![\w-])/
  WEIGHT_SOURCES = Rails.root.glob("app/{views,helpers}/**/*.{erb,rb}").reject do |path|
    path.to_s.include?("app/views/homepage/") || sheet_exception?(path.relative_path_from(Rails.root))
  end.freeze

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

  test "the sheet exception covers the three places of the sheet and nothing else" do
    %w[app/views/catalog/course_sheets/show.html.erb app/views/catalog/course_sheets/blocks/_box.html.erb
       app/javascript/controllers/course_sheet/glossary_controller.js app/assets/stylesheets/course_sheet.css
       app/assets/stylesheets/course_sheet/lens.css].each { assert self.class.sheet_exception?(it), it }

    %w[app/views/catalog/courses/show.html.erb app/views/catalog/course_sheets_extra/show.html.erb
       app/views/catalog/essentials/show.html.erb app/views/homepage/index.html.erb app/helpers/catalog/course_sheet_text_helper.rb
       app/javascript/controllers/course_sheets/x_controller.js app/javascript/controllers/glossary_controller.js
       app/assets/stylesheets/course_sheet_other.css app/assets/stylesheets/application.tailwind.css
       app/views/layouts/application.html.erb].each { assert_not self.class.sheet_exception?(it), it }
  end

  test "outside the sheet, the weight, font and palette rules still apply to every view, helper and script" do
    assert_not_empty WEIGHT_SOURCES
    assert_empty WEIGHT_SOURCES.select { self.class.sheet_exception?(relative(it)) }
    # Seule la règle de police est dispensée dans la fiche ; les autres règles s'y appliquent encore.
    assert_equal [ "police hors tokens" ], SHEET_EXEMPT_RULES
    assert_empty scan(/font-serif/), "font-serif ne passe pas la règle hors fiche"
    # La règle attrape toujours ce qu'elle doit, y compris le gras, hors des dossiers de la fiche.
    assert_match FORBIDDEN_WEIGHT, "font-bold"
    assert_match RULES.fetch("police hors tokens"), "font-serif"
    assert_match RULES.fetch("couleur hexadécimale"), "#fbf6e9"
    assert_match RULES.fetch("attribut `style`"), 'style="color:red"'
  end

  test "Kalam and Source Serif 4 live only in the sheet files, never in another view, helper, script or stylesheet" do
    sources = Rails.root.glob("app/{views,helpers,javascript,assets/stylesheets}/**/*.{erb,rb,js,css}")
    offences = sources.reject { self.class.sheet_exception?(relative(it)) }
                      .select { it.read.match?(SHEET_FONTS) }.map { relative(it) }

    assert_empty offences, "Kalam et Source Serif 4 sont réservées à la fiche de cours (UDR-XXXX) :\n#{offences.join("\n")}"
    assert_match SHEET_FONTS, "font-family: Kalam"
  end

  test "the sheet stylesheet carries the tokens, the 3 themes, the Seyès and the self-hosted fonts" do
    css = Rails.root.join("app/assets/stylesheets/course_sheet.css").read

    %w[blue teal burgundy].each { assert_includes css, %(data-sheet-theme="#{it}") unless it == "blue" }
    %w[--sheet-paper --sheet-ink --sheet-primary --sheet-accent --sheet-note --sheet-success --sheet-error].each { assert_includes css, "#{it}:", it }
    assert_includes css, "--sheet-paper: #fbf6e9;"
    assert_includes css, "--sheet-primary: oklch(0.48 0.15 262);"
    assert_includes css, "--sheet-success: oklch(0.52 0.13 155);"
    assert_includes css, "--sheet-error: oklch(0.53 0.19 27);"
    assert_includes css, "transparent 74px"
    assert_includes css, "transparent 1px 32px"
    assert_includes css, "transparent 1px 8px"
    %w[.sheet-page .sheet-h1 .sheet-h2 .sheet-box .sheet-btn .sheet-feedback .sheet-bubble].each { assert_includes css, "#{it} {", it }

    fonts = css.scan(%r{url\("(/fonts/[^"]+\.woff2)"\)}).flatten
    assert_equal %w[kalam-latin-400-normal kalam-latin-700-normal source-serif-4-latin-wght-italic source-serif-4-latin-wght-normal],
                 fonts.map { File.basename(it, ".woff2") }.sort
    fonts.each { assert Rails.public_path.join(it.delete_prefix("/")).file?, "#{it} manque dans public/" }
    assert Rails.public_path.join("fonts/LICENSE-OFL.txt").file?
    assert_no_match %r{https?://|googleapis|gstatic}, css, "ADR-0049 : aucune ressource tierce"
  end

  test "the sheet stylesheet is served by Propshaft but is not loaded by the application layout" do
    assert Rails.application.assets.load_path.find("course_sheet.css")
    assert_not_includes Rails.root.join("app/views/layouts/application.html.erb").read, "course_sheet"
    assert_not_includes STYLESHEET, "Kalam"
  end

  test "the sheet imports one file per kind family, written by its own lot" do
    css = Rails.root.join("app/assets/stylesheets/course_sheet.css").read

    assert_equal %w[./course_sheet/argument.css ./course_sheet/exercises.css ./course_sheet/lens.css ./course_sheet/reading.css ./course_sheet/thales_figure.css], css.scan(/@import "([^"]+)";/).flatten.sort
    assert_operator css.index("@import"), :<, css.index("@font-face")
  end

  private

  def scan(pattern, skip_sheet: false)
    SOURCES.reject { |path| skip_sheet && self.class.sheet_exception?(relative(path)) }.flat_map do |path|
      path.each_line.with_index(1).flat_map do |line, number|
        line.gsub(SANCTIONED_VARIANT, "").to_enum(:scan, pattern).map { Regexp.last_match }
            .select { |match| !block_given? || yield(match) }
            .map { |match| "#{path.relative_path_from(Rails.root)}:#{number} #{match[0]}" }
      end
    end
  end
end
