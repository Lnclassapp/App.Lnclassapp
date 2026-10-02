require "test_helper"

# UDR-0063 (plan fonctions-espace-eleve, lot P1) : « Notre mission » est une page publique sur le gabarit commun (logo,
# retour « Accueil », un seul h1, une section par h2). En ligne depuis le 2026-10-02 (lot Z, décision du porteur, avant
# la relecture des juristes).
class Communication::MissionPageTest < ActionDispatch::IntegrationTest
  SECTIONS = %w[faire-comprendre pour-qui ce-que-nous-faisons comment-nous-le-faisons].freeze

  test "the page is online: a visitor gets it without signing in" do
    assert Communication::PagesController.online?(:mission)

    get mission_path

    assert_response :success
  end

  test "a visitor reads the page without signing in, under one h1, with « Accueil » back to the root" do
    get mission_path

    assert_response :success
    assert_select "h1", count: 1, text: "Notre mission"
    assert_select "a[href='#{root_path}']", text: /Accueil/
  end

  test "each section of the text has its own h2, anchored by a stable id" do
    assert_equal SECTIONS, sections.keys.map(&:to_s)

    get mission_path

    sections.each do |id, section|
      assert_select "section[aria-labelledby='#{id}']", count: 1 do
        assert_select "h2##{id}", count: 1, text: section[:title]
      end
    end
    assert_select "section[aria-labelledby] h2", count: SECTIONS.size
  end

  test "four sections, five at most: no table of contents" do
    get mission_path

    assert_select "nav[aria-label='Sommaire']", 0
  end

  test "the page names its publisher and lists every item of the text" do
    get mission_path

    assert_select "section[aria-labelledby='faire-comprendre']", text: /Lnclass Côte d'Ivoire SARL, à Tiassalé/
    assert_select "section[aria-labelledby='pour-qui'] li", count: 3
    assert_select "section[aria-labelledby='ce-que-nous-faisons'] li", text: /Bronze, Argent, Or, Diamant/
    assert_select "section[aria-labelledby='comment-nous-le-faisons'] li", text: /^Sans traceur/
  end

  private

  def sections = I18n.t("communication.pages.mission.sections", locale: :fr)
end
