# ADR-0067, chantier politique-cache (lot E): a long list draws its icons once, in <symbol>s, and its rows take them back
# by <use> (ComponentsHelper#ui_icon_sprite). An icon is lost if its <use> finds no <symbol>: inside a frame, the symbols
# must come with the frame, which is all a search or a page change brings back.
module IconSpriteAssertions
  ActionDispatch::IntegrationTest.include(self)

  # scope: the CSS selector of the element that must carry the symbols of its own icons (a frame, a list); at least
  # `minimum` of its icons are taken back by <use>.
  def assert_icons_drawn_once(scope, minimum: 2)
    root = css_select(scope).first
    assert root, "#{scope} absent"
    uses = root.css("svg > use")
    assert_operator uses.size, :>=, minimum, "#{scope} : ses icônes ne passent pas par <use>"
    uses.each { assert root.at_css("symbol#{it['href']}"), "#{scope} : #{it['href']} sans <symbol>" }
    assert_equal root.css("symbol").map { it["id"] }.uniq.size, root.css("symbol").size, "#{scope} : <symbol> en double"
  end
end
