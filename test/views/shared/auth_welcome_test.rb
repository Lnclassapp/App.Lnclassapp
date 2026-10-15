require "test_helper"

# UDR-0088 §3.1, §3.2 : l'accueil bleu de la connexion et de l'inscription élève (carte sous 1 024 px, panneau à gauche
# au-delà) et « Besoin d'aide ? » en haut à droite. Tokens seuls : le thème sombre change leurs valeurs, pas les classes.
class AuthWelcomeTest < ActionView::TestCase
  GRADIENT = %w[bg-linear-to-br from-brand-strong to-brand text-white].freeze

  setup { view.define_singleton_method(:lnclass_app) { nil } }

  def welcome(variant, text: nil)
    render partial: "shared/auth_welcome", locals: { variant:, title: "Heureux de vous revoir", text: }
    Nokogiri::HTML.fragment(rendered)
  end

  test "the card, under 1 024 px: the gradient, the 48 px logo leading home, the title and the sentence" do
    html = welcome(:card, text: "Ton espace d'apprentissage.")
    card = html.at_css("#auth-welcome-card")

    assert_empty GRADIENT - card[:class].split
    assert_includes card[:class].split, "lg:hidden"
    assert_includes card[:class].split, "rounded-card"
    logo = card.at_css("a[href='/'][aria-label='Lnclass, accueil']")
    assert_includes logo.at_css("img[alt='']")[:class].split, "size-12"
    assert_equal "Heureux de vous revoir", card.at_css("p.font-display").text.strip
    assert_includes card.text, "Ton espace d'apprentissage."
  end

  test "the panel, from 1 024 px: half of the screen, the 64 px logo, the title, without a sentence when none is given" do
    html = welcome(:panel)
    panel = html.at_css("aside#auth-welcome-panel")

    assert_empty GRADIENT - panel[:class].split
    assert_empty %w[hidden lg:flex] - panel[:class].split
    assert_includes panel.at_css("a[href='/'][aria-label='Lnclass, accueil'] img[alt='']")[:class].split, "size-16"
    assert_equal "Heureux de vous revoir", panel.at_css("p.font-display").text.strip
    assert_equal 1, panel.css("p").size
  end

  test "an unknown variant is refused" do
    assert_raises(ActionView::Template::Error) { welcome(:banner) }
  end

  test "« Besoin d'aide ? » sits at the top right, bold brand-strong with the headset, and opens the help sheet" do
    render partial: "shared/auth_help"
    html = Nokogiri::HTML.fragment(rendered)
    bar = html.at_css("#auth-help")

    assert_includes bar[:class].split, "justify-end"
    trigger = bar.at_css("[aria-controls='help-sheet']")
    assert_includes trigger.text, "Besoin d'aide ?"
    # Sans JavaScript, le déclencheur est un lien vers la page d'aide.
    assert_equal "/aide", trigger[:href]
    assert_includes trigger[:class], "text-brand-strong!"
    assert bar.at_css("dialog#help-sheet")
  end

  test "the partials and the two pages use tokens only, no colour written by hand, so the dark theme follows" do
    [ "shared/_auth_welcome", "shared/_auth_help", "identity/sessions/new", "classroom/student_registrations/new",
      "classroom/student_registrations/_form" ].each do |partial|
      source = Rails.root.join("app/views/#{partial}.html.erb").read

      assert_no_match(/#\h{3,8}\b|rgb\(|\[(#|rgb)|-(blue|sky|gray|slate|neutral)-\d|\bdark:/, source, partial)
    end
  end
end
