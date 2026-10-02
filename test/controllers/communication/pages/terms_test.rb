require "test_helper"

# UDR-0063 (plan fonctions-espace-eleve, lot P3) : « Conditions d'utilisation » est une page publique sur le gabarit
# commun (logo, retour « Accueil », un seul h1, un sommaire au-delà de cinq sections, une section par h2). Elle répond
# 404 tant qu'elle n'est pas dans Communication::PagesController::ONLINE, après la validation des juristes (lot Z) :
# ces tests la simulent en ligne.
class Communication::TermsPageTest < ActionDispatch::IntegrationTest
  SECTIONS = %w[
    objet-et-editeur comptes pin contenu engagements exercices-et-dates-limites suspension-et-fin vos-donnees
    responsabilite eleves-mineurs droit-applicable modification
  ].freeze

  test "the page stays offline until the lot Z puts it in ONLINE: 404" do
    get terms_path

    assert_response :not_found
  end

  test "a visitor reads the page without signing in, under one h1, with « Accueil » back to the root" do
    online { get terms_path }

    assert_response :success
    assert_select "h1", count: 1, text: "Conditions générales d'utilisation"
    assert_select "a[href='#{root_path}']", text: /Accueil/
    assert_select "body", text: /Mis à jour le\s+2 octobre 2026/
  end

  test "each section of the text has its own h2, anchored by a stable id" do
    assert_equal SECTIONS, sections.keys.map(&:to_s)

    online { get terms_path }

    sections.each do |id, section|
      assert_select "section[aria-labelledby='#{id}']", count: 1 do
        assert_select "h2##{id}", count: 1, text: section[:title]
      end
    end
    assert_select "section[aria-labelledby] h2", count: SECTIONS.size
  end

  test "twelve sections: the table of contents links to every h2, in order" do
    online { get terms_path }

    assert_select "nav[aria-label='Sommaire'] ol li a", count: SECTIONS.size do |links|
      assert_equal SECTIONS.map { "##{it}" }, links.map { it["href"] }
      assert_equal sections.values.map { it[:title] }, links.map { it.text.strip }
    end
  end

  test "the page names its publisher, its two numbers, the PIN rules and the Ivorian law" do
    online { get terms_path }

    publisher = "section[aria-labelledby='objet-et-editeur']"
    assert_select publisher, text: /Lnclass Côte d'Ivoire SARL, Tiassalé, au feu du marché, vers la Pharmacie Saint-Joseph/
    [ "+225 05 44 32 00 20", "+225 05 84 25 80 85" ].each do |phone|
      assert_select publisher, text: /#{Regexp.escape(phone)}/
    end
    assert_select "section[aria-labelledby='pin'] li", text: /15 minutes après 5 échecs, 1 heure après 10/
    assert_select "section[aria-labelledby='engagements'] li", count: 5
    assert_select "section[aria-labelledby='droit-applicable']", text: /droit ivoirien/
  end

  private

  def sections = I18n.t("communication.pages.terms.sections", locale: :fr)

  # The page is offline until the lot Z: online? is simulated for the block only, then restored.
  def online
    original = Communication::PagesController.method(:online?)
    Communication::PagesController.define_singleton_method(:online?) { |*| true }
    yield
  ensure
    Communication::PagesController.define_singleton_method(:online?, original) if original
  end
end
