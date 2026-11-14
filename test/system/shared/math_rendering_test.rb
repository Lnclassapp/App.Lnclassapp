require "application_system_test_case"

# ADR-0051 et TR-41 : KaTeX est un chunk chargé à la demande par le contrôleur math, jamais le point d'entrée commun.
class MathRenderingTest < ApplicationSystemTestCase
  test "une formule d'un élément math est rendue par KaTeX, chargé seulement à ce moment-là" do
    visit root_path

    assert_not katex_loaded?

    page.execute_script(<<~JS)
      document.body.insertAdjacentHTML("beforeend", '<div id="formula" data-controller="math">Aire : $\\\\pi r^2$ et $$x^2 + 1$$</div>')
    JS

    assert_selector "#formula .katex", count: 2
    assert_selector "#formula .katex-display", count: 1
    assert katex_loaded?
  end

  # Un turbo-frame ou un Turbo Stream remplace le contenu sous l'élément porteur sans le reconnecter (formules-apres-soumission).
  test "une formule arrivée après coup sous un élément math déjà connecté est rendue" do
    visit root_path
    page.execute_script(<<~JS)
      document.body.insertAdjacentHTML("beforeend", '<div id="host" data-controller="math"><p>Rien</p></div>')
    JS
    assert_selector "#host", text: "Rien"

    page.execute_script(<<~JS)
      document.querySelector("#host").innerHTML = '<p id="late">Indice : $\\\\overrightarrow{DC}$</p>'
    JS

    assert_selector "#late .katex"
    assert_no_text "overrightarrow{DC}"
  end

  # PR #626, tâche `lecons` : des éléments math imbriqués (la feuille, l'exercice) dont un texte garde un « $ » seul (une formule coupée
  # par une case à remplir) se renvoyaient leurs mutations sans fin, et la page ne se reposait jamais. Le rendu doit se poser.
  test "des éléments math imbriqués avec un « $ » seul se posent, sans mutations sans fin" do
    visit root_path
    page.execute_script(<<~JS)
      window.mutations = 0
      new MutationObserver((records) => { window.mutations += records.length }).observe(document.body, { childList: true, subtree: true, characterData: true })
      document.body.insertAdjacentHTML("beforeend", '<div id="sheet" data-controller="math"><p>Feuille $a$</p><section data-controller="math"><span id="cut" data-controller="math">Loi : $I = \\dfrac{E}{ </span><span data-controller="math">Aire $\\pi r^2$</span></section></div>')
    JS
    assert_selector "#sheet .katex", count: 2

    sleep 1
    settled = page.evaluate_script("window.mutations")
    sleep 1

    assert_operator page.evaluate_script("window.mutations"), :<=, settled + 5, "le DOM mute encore sans que rien ne change"
    assert_operator settled, :<, 100
    assert_text "Loi : $I = \\dfrac{E}{"
  end

  def katex_loaded? = page.evaluate_script("performance.getEntriesByType('resource').some((entry) => entry.name.includes('auto-render'))")

  test "le point d'entrée commun ne contient pas KaTeX" do
    application = Rails.root.join("app/assets/builds/application.js").read

    assert_no_match(/katex/i, application)
    assert(Dir[Rails.root.join("app/assets/builds/*.digested.js")].any? { File.read(it).include?("katex-display") })
  end
end
