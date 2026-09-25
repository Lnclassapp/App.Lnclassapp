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
    "couleur hexadécimale" => /#(?:\h{8}|\h{6}|\h{3,4})\b/,
    "attribut `style`" => /\bstyle\s*[=:]\s*["'{]/,
    "variante `dark:` (pas de mode sombre en V1)" => /(?<![\w-])dark:/,
    "couleur de la palette par défaut" =>
      /(?<![\w-])(?:#{COLOR_UTILITIES.join('|')})-(?:#{DEFAULT_PALETTE.join('|')})(?:-\d+)?(?![\w-])/,
    "rayon hors tokens" => /(?<![\w-])rounded(?:-[trblse]{1,2})?-(?:xs|md|lg|xl|2xl|3xl|4xl)(?![\w-])/,
    "ombre hors tokens" => /(?<![\w-])shadow-(?:2xs|xs|sm|md|lg|xl|2xl|inner)(?![\w-])/,
    "police hors tokens" => /(?<![\w-])font-serif(?![\w-])/
  }.freeze

  SPACING = /(?<![\w-])-?(?:#{SPACING_UTILITIES.join('|')})-(\d+(?:\.\d+)?)(?![\w.\/-])/

  test "the sources exist" do
    assert_operator SOURCES.size, :>, 20
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

  test "the patterns catch what they must" do
    {
      "valeur arbitraire `-[…]`" => %w[w-[26rem] md:grid-cols-[1fr_1.4fr] data-[open]:block],
      "propriété arbitraire `[prop:valeur]`" => [ 'class="[scrollbar-width:none]"' ],
      "couleur hexadécimale" => %w[#fff #00a0ff],
      "couleur de la palette par défaut" => %w[bg-slate-50 text-blue-600 hover:border-gray-200],
      "rayon hors tokens" => %w[rounded-xl rounded-t-2xl],
      "ombre hors tokens" => %w[shadow-lg]
    }.each do |rule, samples|
      samples.each { |sample| assert_match RULES.fetch(rule), sample, "#{rule} devrait refuser #{sample}" }
    end
    %w[rounded-card shadow-pop bg-brand-soft role[:accent] href="#pour-qui" text-ink/60].each do |sample|
      RULES.each_value { |pattern| assert_no_match pattern, sample }
    end
    assert_equal "7", SPACING.match("p-7")[1]
    assert_nil SPACING.match("size-7")
  end

  private

  def scan(pattern)
    SOURCES.flat_map do |path|
      path.each_line.with_index(1).flat_map do |line, number|
        line.to_enum(:scan, pattern).map { Regexp.last_match }
            .select { |match| !block_given? || yield(match) }
            .map { |match| "#{path.relative_path_from(Rails.root)}:#{number} #{match[0]}" }
      end
    end
  end
end
