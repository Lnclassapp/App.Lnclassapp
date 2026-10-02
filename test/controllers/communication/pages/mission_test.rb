require "test_helper"

# UDR-0063 (plan fonctions-espace-eleve, lot P1) : « Notre mission » est une page publique sur le gabarit commun (logo,
# retour « Accueil », un seul h1, une section par h2). Elle répond 404 tant qu'elle n'est pas dans
# Communication::PagesController::ONLINE (lot Z) : ces tests la simulent en ligne.
class Communication::MissionPageTest < ActionDispatch::IntegrationTest
  SECTIONS = %w[faire-comprendre pour-qui ce-que-nous-faisons comment-nous-le-faisons].freeze

  test "the page stays offline until the lot Z puts it in ONLINE: 404" do
    get mission_path

    assert_response :not_found
  end

  test "a visitor reads the page without signing in, under one h1, with « Accueil » back to the root" do
    online { get mission_path }

    assert_response :success
    assert_select "h1", count: 1, text: "Notre mission"
    assert_select "a[href='#{root_path}']", text: /Accueil/
  end

  test "each section of the text has its own h2, anchored by a stable id" do
    assert_equal SECTIONS, sections.keys.map(&:to_s)

    online { get mission_path }

    sections.each do |id, section|
      assert_select "section[aria-labelledby='#{id}']", count: 1 do
        assert_select "h2##{id}", count: 1, text: section[:title]
      end
    end
    assert_select "section[aria-labelledby] h2", count: SECTIONS.size
  end

  test "four sections, five at most: no table of contents" do
    online { get mission_path }

    assert_select "nav[aria-label='Sommaire']", 0
  end

  test "the page names its publisher and lists every item of the text" do
    online { get mission_path }

    assert_select "section[aria-labelledby='faire-comprendre']", text: /Lnclass Côte d'Ivoire SARL, à Tiassalé/
    assert_select "section[aria-labelledby='pour-qui'] li", count: 3
    assert_select "section[aria-labelledby='ce-que-nous-faisons'] li", text: /Bronze, Argent, Or, Diamant/
    assert_select "section[aria-labelledby='comment-nous-le-faisons'] li", text: /^Sans traceur/
  end

  private

  def sections = I18n.t("communication.pages.mission.sections", locale: :fr)

  # The page is offline until the lot Z: online? is simulated for the block only, then restored.
  def online
    original = Communication::PagesController.method(:online?)
    Communication::PagesController.define_singleton_method(:online?) { |*| true }
    yield
  ensure
    Communication::PagesController.define_singleton_method(:online?, original) if original
  end
end
