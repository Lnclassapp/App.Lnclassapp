require "test_helper"

# UDR XXXX écrans minimalistes style Wave §3 : la flèche retour et le grand titre, le groupe de lignes (3 puis « Voir plus (n) »)
# et la ligne plate à valeur alignée à droite. Tokens seuls : le thème sombre change leurs valeurs, pas les classes.
class ScreensTest < ActionView::TestCase
  def group(total:)
    output = view.render(layout: "shared/screens/group", locals: { id: "lessons", title: "Prépare interros", total: }) do
      view.safe_join(Array.new(total) do |index|
        view.render("shared/screens/row", title: "Interro #{index + 1}", href: "/x/#{index}", icon: "i", value: "0/4", folded: index >= 3)
      end)
    end
    Nokogiri::HTML.fragment(output)
  end

  test "the inner header: back arrow of 48 px, big title, subtitle" do
    render partial: "shared/screens/inner_header", locals: { title: "Vecteurs", back_href: "/courses", subtitle: "Leçon 1 · Maths" }
    html = Nokogiri::HTML.fragment(rendered)

    back = html.at_css("a#inner_back")
    assert_equal "/courses", back[:href]
    assert_equal "Retour", back[:"aria-label"]
    assert_includes back[:class].split, "size-tap"
    assert_equal "Vecteurs", html.at_css("h1").text.strip
    assert_equal "Leçon 1 · Maths", html.at_css("#inner_subtitle").text.strip
  end

  test "a group of three rows has no « Voir plus »" do
    html = group(total: 3)

    assert_empty html.css("button[data-reveal-target='button']")
    assert_equal 3, html.css("li:not([hidden])").size
    assert_equal "Prépare interros", html.at_css("h2").text.strip
  end

  test "a group of five rows shows three, hides two and counts them in « Voir plus (2) »" do
    html = group(total: 5)

    assert_equal 3, html.css("li:not([hidden])").size
    assert_equal 2, html.css("li[hidden]").size
    assert_equal "Voir plus (2)", html.at_css("button[data-reveal-target='button']").text.strip
    assert_equal "reveal", html.at_css("div[data-controller]")[:"data-controller"]
  end

  test "a row is one link of 48 px with its value on the right" do
    html = group(total: 1)

    link = html.at_css("li > a")
    assert_includes link[:class].split, "min-h-tap"
    assert_equal "0/4", link.css("span").last.text.strip
    assert_includes link.css("span").last[:class].split, "tabular-nums"
  end
end
