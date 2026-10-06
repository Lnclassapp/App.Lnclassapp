require "test_helper"

# Chantier politique-cache, lot E5 (A) : les badges et les cartes-liens portent une classe partagée au lieu de leur liste
# de classes Tailwind. Le rendu doit rester celui d'avant : chaque classe partagée applique exactement l'ancienne liste,
# et les helpers n'émettent plus que la classe partagée.
class SharedClassesTest < ActiveSupport::TestCase
  STYLESHEET = Rails.root.join("app/assets/stylesheets/application.tailwind.css").read

  # Les listes que ComponentsHelper écrivait sur chaque élément jusqu'au 2026-10-05.
  BEFORE = {
    "ui-badge" => "inline-flex items-center gap-1.5 rounded-full font-medium whitespace-nowrap",
    # UDR-0005, amendement du 2026-10-06 (ux-pages-eleve) : le petit badge passe de 11 à 12 px.
    "ui-badge-sm" => "px-2 py-0.5 text-xs",
    "ui-badge-md" => "px-2.5 py-1 text-xs",
    "ui-card-link" => "transition duration-300 ease-out hover:-translate-y-1 hover:border-brand/40 hover:shadow-lift " \
                      "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand",
    # Lot E6 : boutons, bouton icône, menu ⋮, boîte de dialogue et avatar.
    "ui-button" => "relative inline-flex cursor-pointer items-center justify-center rounded-full font-medium whitespace-nowrap " \
                   "select-none transition active:scale-95 focus-visible:outline-2 focus-visible:outline-offset-2 " \
                   "focus-visible:outline-brand disabled:pointer-events-none disabled:opacity-50 " \
                   "aria-disabled:pointer-events-none aria-disabled:opacity-50",
    "ui-button-primary" => "bg-ink text-white hover:bg-ink/85",
    "ui-button-brand" => "bg-brand text-ink hover:bg-brand/85",
    "ui-button-secondary" => "border border-line bg-white text-ink hover:bg-mist",
    "ui-button-ghost" => "text-ink hover:bg-ink/5",
    "ui-button-danger" => "bg-error text-white hover:bg-error/90",
    "ui-button-sm" => "h-10 gap-1.5 px-4 text-sm after:absolute after:-inset-1",
    "ui-button-md" => "min-h-tap gap-2 px-5 text-sm",
    "ui-button-lg" => "min-h-14 gap-2 px-6 text-base",
    "ui-icon-button" => "grid size-tap cursor-pointer place-items-center rounded-full text-mute transition hover:bg-ink/5 " \
                        "hover:text-ink focus-visible:outline-2 focus-visible:outline-brand",
    "ui-menu" => "absolute mt-2 w-64 rounded-ln border border-line bg-white p-1.5 shadow-pop animate-fade-in",
    "ui-menu-item" => "flex min-h-tap w-full items-center gap-3 rounded-sm px-3 text-sm font-medium focus:outline-none",
    "ui-menu-item-default" => "text-ink hover:bg-mist focus:bg-mist",
    "ui-menu-item-danger" => "text-error hover:bg-error-soft focus:bg-error-soft",
    "ui-dialog" => "m-auto w-full max-w-none rounded-sheet bg-white p-0 text-ink shadow-pop backdrop:bg-ink/50 " \
                   "open:animate-slide-up max-sm:mb-0 max-sm:rounded-b-none",
    "ui-avatar" => "inline-grid shrink-0 place-items-center overflow-hidden rounded-full font-display font-extrabold"
  }.freeze

  def applied(utility)
    STYLESHEET[/@utility #{Regexp.escape(utility)} \{\s*@apply ([^;]+);\s*\}/, 1]&.split
  end

  test "each shared class applies exactly the former list, nothing more" do
    BEFORE.each { |utility, classes| assert_equal classes.split, applied(utility), utility }
  end

  test "the helpers write the shared class, never the former list" do
    assert_equal "ui-badge", ComponentsHelper::BADGE_BASE
    assert_equal({ sm: "ui-badge-sm", md: "ui-badge-md" }, ComponentsHelper::BADGE_SIZES)
    assert_equal "ui-card-link", ComponentsHelper::CARD_LINK
    assert_equal "ui-button", ComponentsHelper::BUTTON_BASE
    assert_equal %i[primary brand secondary ghost danger].index_with { "ui-button-#{it}" }, ComponentsHelper::BUTTON_VARIANTS
    assert_equal %i[sm md lg].index_with { "ui-button-#{it}" }, ComponentsHelper::BUTTON_SIZES
    assert_equal({ default: "ui-menu-item-default", danger: "ui-menu-item-danger" }, ComponentsHelper::DROPDOWN_TONES)
  end

  # Tailwind ne génère une @utility que si son nom figure en toutes lettres dans les fichiers qu'il lit (@source) : un nom
  # construit par interpolation ("ui-button-#{variant}") n'existe pas dans le CSS, et le bouton perd sa forme.
  test "every shared class is written literally where Tailwind reads it" do
    sources = %w[views helpers javascript].flat_map { Rails.root.glob("app/#{it}/**/*.{rb,erb,js}") }.map(&:read).join("\n")

    BEFORE.each_key { |utility| assert sources.match?(/["' ]#{Regexp.escape(utility)}["' ]/), "#{utility} absent des sources" }
  end

  # Le menu ⋮, la boîte de dialogue et les boutons icônes des composants n'écrivent plus que la classe partagée.
  test "the component partials use the shared classes" do
    partial = ->(name) { Rails.root.join("app/views/components/_#{name}.html.erb").read }

    assert_includes partial.(:dropdown), 'class="ui-icon-button"'
    assert_includes partial.(:dropdown), 'class="ui-menu '
    assert_includes partial.(:modal), 'class="ui-dialog '
    assert_includes partial.(:modal), 'class="ui-icon-button -mt-2 -mr-2 shrink-0"'
    assert_includes partial.(:toast), 'class="ui-icon-button -my-2 shrink-0"'
  end
end
