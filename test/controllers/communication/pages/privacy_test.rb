require "test_helper"

# UDR-0063 (plan fonctions-espace-eleve, lot P2) : « Protection des données » est une page publique sur le gabarit
# commun (logo, retour « Accueil », un seul h1, un sommaire au-delà de cinq sections, une section par h2). Elle répond
# 404 tant qu'elle n'est pas dans Communication::PagesController::ONLINE, après le lot R et la validation des juristes
# (lot Z) : ces tests la simulent en ligne.
class Communication::PrivacyPageTest < ActionDispatch::IntegrationTest
  SECTIONS = %w[
    qui-est-responsable cadre-applicable donnees-collectees finalites qui-voit-vos-donnees ou-sont-vos-donnees
    securite conservation vos-droits eleves-mineurs modification
  ].freeze
  PHONES = [ "+225 05 44 32 00 20", "+225 05 84 25 80 85" ].freeze

  test "the page stays offline until the lot Z puts it in ONLINE: 404" do
    get privacy_path

    assert_response :not_found
  end

  test "a visitor reads the page without signing in, under one h1, with « Accueil » back to the root" do
    online { get privacy_path }

    assert_response :success
    assert_select "h1", count: 1, text: "Protection de vos données personnelles"
    assert_select "a[href='#{root_path}']", text: /Accueil/
    assert_select "body", text: /Mis à jour le\s+2 octobre 2026/
  end

  test "each section of the text has its own h2, anchored by a stable id" do
    assert_equal SECTIONS, sections.keys.map(&:to_s)

    online { get privacy_path }

    sections.each do |id, section|
      assert_select "section[aria-labelledby='#{id}']", count: 1 do
        assert_select "h2##{id}", count: 1, text: section[:title]
      end
    end
    assert_select "section[aria-labelledby] h2", count: SECTIONS.size
  end

  test "eleven sections: the table of contents links to every h2, in order" do
    online { get privacy_path }

    assert_select "nav[aria-label='Sommaire'] ol li a", count: SECTIONS.size do |links|
      assert_equal SECTIONS.map { "##{it}" }, links.map { it["href"] }
      assert_equal sections.values.map { it[:title] }, links.map { it.text.strip }
    end
  end

  test "the page names the data controller, its address, its two numbers and the Ivorian law" do
    online { get privacy_path }

    responsible = "section[aria-labelledby='qui-est-responsable']"
    assert_select responsible, text: /Lnclass Côte d'Ivoire SARL, Tiassalé, au feu du marché, vers la Pharmacie Saint-Joseph/
    PHONES.each do |phone|
      assert_select responsible, text: /#{Regexp.escape(phone)}/
      assert_select "section[aria-labelledby='vos-droits']", text: /#{Regexp.escape(phone)}/
    end
    assert_select "section[aria-labelledby='cadre-applicable']", text: /loi ivoirienne n° 2013-450 du 19 juin 2013.*ARTCI/m
  end

  test "the tables of the draft read as lists: one line per kind of data, one per purpose" do
    online { get privacy_path }

    assert_select "section[aria-labelledby='donnees-collectees'] li", count: 12
    assert_select "section[aria-labelledby='donnees-collectees'] li", text: /^Ce que nous n'enregistrons pas/
    assert_select "section[aria-labelledby='finalites'] li", count: 6
  end

  # ADR-0036, amendment (2), lot R2: a deleted account takes its results with it and leaves every statistic.
  test "§8 says that a deletion erases the results too, and the question to the lawyers is settled" do
    online { get privacy_path }

    conservation = "section[aria-labelledby='conservation']"
    assert_select "#{conservation} li", text: /30 jours.*vos résultats aussi : exercices faits, réponses, notes, badges et fiches à revoir/m
    assert_select "#{conservation} li", text: /n'apparaissez plus dans aucun chiffre de vos classes ni de l'établissement/
    assert_select "#{conservation} li", text: /‹/, count: 0
  end

  private

  def sections = I18n.t("communication.pages.privacy.sections", locale: :fr)

  # The page is offline until the lot Z: online? is simulated for the block only, then restored.
  def online
    original = Communication::PagesController.method(:online?)
    Communication::PagesController.define_singleton_method(:online?) { |*| true }
    yield
  ensure
    Communication::PagesController.define_singleton_method(:online?, original) if original
  end
end
