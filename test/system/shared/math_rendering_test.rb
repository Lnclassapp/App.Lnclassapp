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

  def katex_loaded? = page.evaluate_script("performance.getEntriesByType('resource').some((entry) => entry.name.includes('auto-render'))")

  test "le point d'entrée commun ne contient pas KaTeX" do
    application = Rails.root.join("app/assets/builds/application.js").read

    assert_no_match(/katex/i, application)
    assert(Dir[Rails.root.join("app/assets/builds/*.digested.js")].any? { File.read(it).include?("katex-display") })
  end
end
