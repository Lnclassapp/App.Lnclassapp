require "test_helper"

# UDR-0063 §3.1, §3.4 : le pied de page de la homepage, /aide et la carte d'aide lisent la même liste ; un lien
# n'apparaît que si sa page est en ligne.
class PublicPagesHelperTest < ActionView::TestCase
  CONTROLLER = Communication::PagesController

  setup { @online = CONTROLLER.method(:online?) }
  teardown { CONTROLLER.define_singleton_method(:online?, @online) }

  def simulate_online(*pages)
    CONTROLLER.define_singleton_method(:online?) { |page| pages.include?(page.to_sym) }
  end

  test "no link while no page is online" do
    assert_empty public_page_links
    assert_empty public_page_links(%i[privacy terms])
  end

  test "every online page, in the order of PAGES, with its label and its address" do
    simulate_online(*CONTROLLER::PAGES)

    assert_equal [
      [ "Notre mission", "/mission" ],
      [ "Protection des données", "/confidentialite" ],
      [ "Conditions d'utilisation", "/conditions-utilisation" ],
      [ "Conditions de vente", "/conditions-vente" ]
    ], public_page_links
  end

  test "a page out of ONLINE has no link, and a caller may ask for some pages only" do
    simulate_online(:mission, :terms)

    assert_equal [ [ "Notre mission", "/mission" ], [ "Conditions d'utilisation", "/conditions-utilisation" ] ],
                 public_page_links
    assert_equal [ [ "Conditions d'utilisation", "/conditions-utilisation" ] ], public_page_links(%i[privacy terms])
  end

  test "an unknown page is refused" do
    assert_raises(ArgumentError) { public_page_links(%i[legal]) }
  end
end
