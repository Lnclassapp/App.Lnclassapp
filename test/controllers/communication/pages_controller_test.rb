require "test_helper"
require "action_view/testing/resolvers"

# UDR-0063 : quatre pages publiques et statiques, sur le motif de /aide. Une page hors de ONLINE répond 404 et
# aucun lien n'y mène ; une page en ligne rend le gabarit commun (logo, retour « Accueil », un seul h1, un h2 ancré
# par section, sommaire au-delà de cinq sections).
#
# Les textes des pages appartiennent aux lots P : ce test rend le gabarit avec des pages fictives (locales posées
# ici, sous des clés qu'aucun lot n'utilise), servies par les actions réelles grâce à des vues de test.
class Communication::PagesControllerTest < ActionDispatch::IntegrationTest
  CONTROLLER = Communication::PagesController
  PATHS = { mission: "/mission", privacy: "/confidentialite", terms: "/conditions-utilisation",
            sales_terms: "/conditions-vente" }.freeze

  SHORT_PAGE = {
    page_title: "Page courte", title: "Une page courte",
    sections: {
      "premiere-section": { title: "Première section", paragraphs: [ "Un premier paragraphe.", "Un second." ] },
      "seconde-section": { title: "Seconde section", items: [ "Un point.", "Un autre point." ] }
    }
  }.freeze

  LONG_PAGE = {
    page_title: "Page longue", title: "Une page longue", updated_on: "2 octobre 2026",
    sections: (1..6).to_h { [ :"section-#{it}", { title: "Section #{it}", paragraphs: [ "Texte #{it}." ] } ] }
  }.freeze

  setup do
    @online = CONTROLLER.method(:online?)
    @view_paths = CONTROLLER.view_paths
    I18n.backend.store_translations(:fr, communication: { pages: { lot0b_short: SHORT_PAGE, lot0b_long: LONG_PAGE } })
    CONTROLLER.prepend_view_path(ActionView::FixtureResolver.new(
      "communication/pages/mission.html.erb" => '<% page_title t("communication.pages.lot0b_short.page_title") %><%= render "communication/pages/page", page: :lot0b_short %>',
      "communication/pages/terms.html.erb" => '<% page_title t("communication.pages.lot0b_long.page_title") %><%= render "communication/pages/page", page: :lot0b_long %>'
    ))
  end

  teardown do
    CONTROLLER.define_singleton_method(:online?, @online)
    CONTROLLER.view_paths = @view_paths
    I18n.reload!
  end

  def simulate_online(*pages)
    CONTROLLER.define_singleton_method(:online?) { |page| pages.include?(page.to_sym) }
  end

  test "the four pages are drawn at their French addresses" do
    PATHS.each do |page, path|
      assert_recognizes({ controller: "communication/pages", action: page.to_s }, path)
      assert_equal path, public_send(:"#{page}_path")
    end
  end

  # Lot Z, décision du porteur du 2026-10-02 : les quatre pages sont en ligne, avant la relecture des juristes.
  test "the four pages are online: the list is closed, frozen and names only pages of PAGES" do
    assert_equal %i[mission privacy terms sales_terms], CONTROLLER::ONLINE
    assert_predicate CONTROLLER::ONLINE, :frozen?
    assert_equal %i[mission privacy terms sales_terms], CONTROLLER::PAGES
    assert_empty CONTROLLER::ONLINE - CONTROLLER::PAGES, "ONLINE ne nomme que des pages de PAGES"
    CONTROLLER::PAGES.each { assert CONTROLLER.online?(it) }
  end

  test "online? reads ONLINE, by symbol or by name" do
    online = CONTROLLER::ONLINE
    CONTROLLER.send(:remove_const, :ONLINE)
    CONTROLLER.const_set(:ONLINE, %i[mission].freeze)

    assert CONTROLLER.online?(:mission)
    assert CONTROLLER.online?("mission")
    assert_not CONTROLLER.online?(:terms)
  ensure
    CONTROLLER.send(:remove_const, :ONLINE)
    CONTROLLER.const_set(:ONLINE, online)
  end

  test "every page out of ONLINE answers 404, to a visitor as to a signed-in student" do
    simulate_online

    PATHS.each_value do |path|
      get path

      assert_response :not_found
    end

    sign_in_as create_student(classroom: create_classroom)
    get "/mission"

    assert_response :not_found
  end

  test "a page put online leaves the others at 404" do
    simulate_online(:mission)

    get "/mission"
    assert_response :success

    get "/conditions-utilisation"
    assert_response :not_found
  end

  test "an online page follows the entry screens: logo, back to « Accueil », a single h1" do
    simulate_online(:mission)

    get "/mission"

    assert_response :success
    assert_select "title", "Page courte · Lnclass"
    assert_select "main .max-w-prose", 1
    assert_select "a[href='#{root_path}'] img[src*='lnclass']", 1
    assert_select "nav a[href='#{root_path}']", text: /Accueil/
    assert_select "h1", count: 1, text: "Une page courte"
  end

  test "each section is labelled by its anchored h2, its paragraphs and items in order" do
    simulate_online(:mission)

    get "/mission"

    assert_select "section[aria-labelledby]", 2
    assert_select "section[aria-labelledby='premiere-section'] > h2#premiere-section", text: "Première section"
    assert_select "section[aria-labelledby='premiere-section'] p", count: 2
    assert_select "section[aria-labelledby='seconde-section'] li", 2 do |items|
      assert_equal [ "Un point.", "Un autre point." ], items.map(&:text)
    end
    assert_select "h2", 2
    assert_select "h3, h4", 0
  end

  test "five sections or fewer: no table of contents, no update date" do
    simulate_online(:mission)

    get "/mission"

    assert_select "nav[aria-label='Sommaire']", 0
    assert_no_match(/Mis à jour le/, response.body)
  end

  test "more than five sections: a table of contents links each h2, and the update date shows" do
    simulate_online(:terms)

    get "/conditions-utilisation"

    assert_response :success
    assert_select "h1", count: 1, text: "Une page longue"
    assert_select "p", text: "Mis à jour le 2 octobre 2026"
    assert_select "nav[aria-label='Sommaire'] ol > li > a", 6 do |links|
      assert_equal (1..6).map { "#section-#{it}" }, links.map { it["href"] }
    end
    (1..6).each { assert_select "h2#section-#{it}", "Section #{it}" }
  end

  test "/aide carries « Vos données » only when one of its pages is online" do
    simulate_online
    get help_path

    assert_select "#help_your_data", 0

    simulate_online(:privacy, :terms)
    get help_path

    assert_select "#help_your_data", text: /\AVos données : Protection des données · Conditions d'utilisation\z/
    assert_select "#help_your_data a[href='/confidentialite']", "Protection des données"
    assert_select "#help_your_data a[href='/conditions-utilisation']", "Conditions d'utilisation"
  end
end
