require "test_helper"

# UDR-0063 (plan fonctions-espace-eleve, lot P4) : « Conditions de vente » est une page publique sur le gabarit commun
# (logo, retour « Accueil », un seul h1, un sommaire au-delà de cinq sections, une section par h2). L'offre vient du
# porteur (2026-10-02, grill du chantier abonnement-mobile-money, Q1 à Q8). La page répond 404 tant qu'elle n'est pas
# dans Communication::PagesController::ONLINE, après la validation des juristes (lot Z) : ces tests la simulent en ligne.
class Communication::SalesTermsPageTest < ActionDispatch::IntegrationTest
  SECTIONS = %w[
    vendeur offre-et-prix periode-gratuite paiement duree-et-renouvellement sans-abonnement
    retractation-et-remboursement reclamation responsabilite droit-applicable
  ].freeze

  test "the page stays offline until the lot Z puts it in ONLINE: 404" do
    get sales_terms_path

    assert_response :not_found
  end

  test "a visitor reads the page without signing in, under one h1, with « Accueil » back to the root" do
    online { get sales_terms_path }

    assert_response :success
    assert_select "title", text: /\AConditions de vente · /
    assert_select "h1", count: 1, text: "Conditions générales de vente"
    assert_select "a[href='#{root_path}']", text: /Accueil/
    assert_select "body", text: /Mis à jour le\s+2 octobre 2026/
  end

  test "each section of the text has its own h2, anchored by a stable id" do
    assert_equal SECTIONS, sections.keys.map(&:to_s)

    online { get sales_terms_path }

    sections.each do |id, section|
      assert_select "section[aria-labelledby='#{id}']", count: 1 do
        assert_select "h2##{id}", count: 1, text: section[:title]
      end
    end
    assert_select "section[aria-labelledby] h2", count: SECTIONS.size
  end

  test "ten sections: the table of contents links to every h2, in order" do
    online { get sales_terms_path }

    assert_select "nav[aria-label='Sommaire'] ol li a", count: SECTIONS.size do |links|
      assert_equal SECTIONS.map { "##{it}" }, links.map { it["href"] }
      assert_equal sections.values.map { it[:title] }, links.map { it.text.strip }
    end
  end

  test "the page names the seller, the price, the free days, the 7-day refund and Wave" do
    online { get sales_terms_path }

    assert_select "section[aria-labelledby='vendeur']", text: /Lnclass Côte d'Ivoire SARL/
    assert_select "section[aria-labelledby='offre-et-prix']", text: /16 000 F CFA pour l'année scolaire/
    assert_select "section[aria-labelledby='offre-et-prix']", text: /plein tarif, sans prorata/
    free_days = "section[aria-labelledby='periode-gratuite']"
    assert_select "#{free_days} li", count: 3
    assert_select "#{free_days} li", text: /pendant 14 jours, vous avez accès à tout Lnclass/
    assert_select "#{free_days} li", text: /du 15e au 30e jour/
    assert_select "section[aria-labelledby='sans-abonnement']", text: /ne pouvez pas en commencer/
    assert_select "section[aria-labelledby='retractation-et-remboursement']", text: /dans les 7 jours qui suivent le paiement/
    assert_select "section[aria-labelledby='paiement']", text: /numéro de transaction Wave sert de reçu/
    assert_select "section[aria-labelledby='duree-et-renouvellement']", text: /aucun prélèvement automatique/
  end

  private

  def sections = I18n.t("communication.pages.sales_terms.sections", locale: :fr)

  # The page is offline until the lot Z: online? is simulated for the block only, then restored.
  def online
    original = Communication::PagesController.method(:online?)
    Communication::PagesController.define_singleton_method(:online?) { |*| true }
    yield
  ensure
    Communication::PagesController.define_singleton_method(:online?, original) if original
  end
end
