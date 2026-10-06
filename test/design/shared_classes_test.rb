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
                      "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
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
  end
end
