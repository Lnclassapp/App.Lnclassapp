require "test_helper"

# Le balisage en ligne d'une fiche de révision : tout est échappé d'abord, puis seuls le gras et l'italique deviennent du HTML ;
# `$…$` reste tel quel pour KaTeX.
class Catalog::SheetTextHelperTest < ActionView::TestCase
  test "everything is escaped, scripts included" do
    html = sheet_text(%(<script>alert("x")</script> & <b>b</b>))

    assert_not_includes html, "<script"
    assert_not_includes html, "<b>b"
    assert_includes html, "&lt;script&gt;"
    assert_includes html, "&amp;"
  end

  test "a lexicon mark leaves only its word, escaped" do
    assert_equal "Deux droites sécantes en A.", sheet_text("Deux droites [[secantes|sécantes]] en A.")
    assert_not_includes sheet_text("[[secantes|<img src=x onerror=1>]]"), "<img"
  end

  test "bold and italic" do
    assert_equal "un <b>gras</b> et un <i>italique</i>.", sheet_text("un **gras** et un *italique*.")
  end

  test "a formula between dollars is left to KaTeX, untouched by bold and italic" do
    html = sheet_text("Si $a*b*c$ et $\\frac{AM}{AB} < 1$ alors **oui**.")

    assert_includes html, "$a*b*c$"
    assert_includes html, "$\\frac{AM}{AB} &lt; 1$"
    assert_includes html, "<b>oui</b>"
  end

  # lecons-defauts-affichage : 27 leçons montraient des « ** » à l'élève.
  test "bold around a formula stays bold, formula untouched" do
    html = sheet_text("est **le nombre positif dont le carré est $a*b$**. Donc")

    assert_equal "est <b>le nombre positif dont le carré est $a*b$</b>. Donc", html
  end

  test "a centred $$ formula does not shift the dollars that follow" do
    html = sheet_text("Elle vaut $$E = m*c^2.$$ Elle se mesure en **joules** (J), avec $m$ en kg.")

    assert_equal "Elle vaut $$E = m*c^2.$$ Elle se mesure en <b>joules</b> (J), avec $m$ en kg.", html
  end

  test "a lone dollar is plain text and does not swallow bold" do
    assert_equal "Prix : 5 $ et <b>gras</b>.", sheet_text("Prix : 5 $ et **gras**.")
  end

  test "the result is html safe and nil gives an empty string" do
    assert_predicate sheet_text("x"), :html_safe?
    assert_equal "", sheet_text(nil)
  end
end
