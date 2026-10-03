require "test_helper"

# UDR-0063 §3.1, §3.4 : le pied de page de la homepage, /aide et la carte d'aide lisent la même liste ; un lien
# n'apparaît que si sa page est en ligne. UDR-0066 §3.5 : le lien « Blog » n'existe qu'à partir du premier article
# publié (BL-06), au prix d'une requête par rendu.
class PublicPagesHelperTest < ActionView::TestCase
  CONTROLLER = Communication::PagesController

  setup { @online = CONTROLLER.method(:online?) }
  teardown { CONTROLLER.define_singleton_method(:online?, @online) }

  def simulate_online(*pages)
    CONTROLLER.define_singleton_method(:online?) { |page| pages.include?(page.to_sym) }
  end

  test "no link while no page is online" do
    simulate_online

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

  test "BL-06: no « Blog » link while no article is published, drafts and archived articles included" do
    author = create_team_member(team_role: "content", second_factor: false)
    create_article(author:, status: "draft")
    create_article(author:, status: "archived")

    assert_nil blog_link
  end

  test "BL-06: the « Blog » link appears with the first published article" do
    create_article

    assert_equal [ "Blog", "/blog" ], blog_link
  end

  test "blog_link costs one query a render, whatever the number of footers that read it" do
    assert_queries_count(1) { 2.times { assert_nil blog_link } }
  end
end
