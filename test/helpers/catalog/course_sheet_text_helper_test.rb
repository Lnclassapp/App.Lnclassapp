require "test_helper"

# CA-5, CA-6 — le balisage en ligne d'une fiche de cours : tout est échappé d'abord, puis seules les marques connues
# (mot du lexique, gras, italique) deviennent du HTML ; `$…$` reste tel quel pour KaTeX.
class Catalog::CourseSheetTextHelperTest < ActionView::TestCase
  GLOSSARY = { "secantes" => [ "Sécantes", "Elles se croisent.", "" ] }.freeze

  def render_text(text, glossary: GLOSSARY) = sheet_text(text, glossary:)

  test "everything is escaped, scripts included" do
    html = render_text(%(<script>alert("x")</script> & <b>b</b>))

    assert_not_includes html, "<script"
    assert_not_includes html, "<b>b"
    assert_includes html, "&lt;script&gt;"
    assert_includes html, "&amp;"
  end

  test "a glossary mark becomes a clickable word that names its key" do
    html = render_text("Deux droites [[secantes|sécantes]] en A.")

    assert_dom_equal(
      %(Deux droites <button type="button" class="sheet-word" data-action="course-sheet--glossary#open" data-course-sheet--glossary-key-param="secantes">sécantes</button> en A.),
      html
    )
  end

  test "a mark whose key is not in the glossary is plain text" do
    html = render_text("Un mot [[inconnu|perdu]] ici.")

    assert_equal "Un mot perdu ici.", html
  end

  test "a hostile word in a mark is escaped" do
    html = render_text("[[secantes|<img src=x onerror=1>]]")

    assert_not_includes html, "<img"
    assert_includes html, "&lt;img"
  end

  test "bold and italic" do
    assert_equal "un <b>gras</b> et un <i>italique</i>.", render_text("un **gras** et un *italique*.")
  end

  test "a word of the glossary can be bold" do
    html = render_text("**[[secantes|sécantes]]**")

    assert_match(%r{\A<b><button.*>sécantes</button></b>\z}, html)
  end

  test "a formula between dollars is left to KaTeX, untouched by bold and italic" do
    html = render_text("Si $a*b*c$ et $\\frac{AM}{AB} < 1$ alors **oui**.")

    assert_includes html, "$a*b*c$"
    assert_includes html, "$\\frac{AM}{AB} &lt; 1$"
    assert_includes html, "<b>oui</b>"
  end

  test "the result is html safe and nil gives an empty string" do
    assert_predicate render_text("x"), :html_safe?
    assert_equal "", render_text(nil)
  end
end
