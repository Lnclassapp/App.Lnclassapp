require "application_system_test_case"

# PRD « Molécules » côté rendu : alcanes (développé, semi-développé, brut), curseur carbons, dessin libre, valence refusée par le navigateur.
class Catalog::FigureMoleculeSystemTest < ApplicationSystemTestCase
  def figure(params:, controls: [])
    Entities::Catalog::Figure.new(key: "figure-test", kind: "molecule", params:, controls:,
                                  description: Factories::RevisionSheet::FIGURE_DESCRIPTION)
  end

  def render_html(figure) = ApplicationController.render(partial: "catalog/figures/figure", locals: { figure: })

  def mount(figure) = mount_html(render_html(figure))

  def mount_html(html)
    visit new_session_path
    page.execute_script(<<~JS, html)
      document.getElementById("host")?.remove()
      const host = document.createElement("div")
      host.id = "host"
      host.style.maxWidth = "640px"
      host.innerHTML = arguments[0]
      document.body.prepend(host)
    JS
  end

  def alkane(carbons, display, controls: []) = figure(params: { "mode" => "alkane", "carbons" => carbons, "display" => display }, controls:)

  def atoms(*triples) = triples.each_with_index.map { |(element, x, y), index| { "id" => "a#{index}", "element" => element, "x" => x, "y" => y } }

  # Une valeur posée dans le HTML après coup : l'entité Figure (et le domaine, une fois la valence contrôlée) la refuserait,
  # alors que la page peut recevoir n'importe quoi.
  def tamper(figure, from, to)
    html = render_html(figure)
    changed = html.sub(from, to)
    assert_not_equal html, changed, "la valeur à remplacer est absente du HTML"
    mount_html(changed)
  end

  test "a developed propane draws 3 C, 8 H, 10 bonds, its name and its formula" do
    mount(alkane(3, "developed"))

    assert_selector "#host svg [data-atom=C]", count: 3, visible: :all
    assert_selector "#host svg [data-atom=H]", count: 8, visible: :all
    assert_selector "#host svg [data-bond]", count: 10, visible: :all
    assert_selector "#host svg text[data-name]", text: "propane", visible: :all
    assert_selector "#host svg text[data-formula]", text: "C₃H₈", visible: :all
    assert_selector "#host [data-figure-state=ready]", visible: :all
  end

  test "the carbons slider rebuilds the chain, the name and announces it" do
    mount(alkane(3, "developed", controls: [ { "param" => "carbons", "min" => 1, "max" => 10, "step" => 1, "label" => "atomes de carbone" } ]))

    find("input[type=range]").set(1)
    assert_selector "#host svg text[data-name]", text: "méthane", visible: :all
    assert_selector "#host svg text[data-formula]", text: "CH₄", visible: :all
    assert_selector "#host svg [data-atom=C]", count: 1, visible: :all
    assert_selector "#host svg [data-atom=H]", count: 4, visible: :all
    assert_selector "#host svg [data-bond]", count: 4, visible: :all

    find("input[type=range]").set(10)
    assert_selector "#host svg text[data-name]", text: "décane", visible: :all
    assert_selector "#host svg text[data-formula]", text: "C₁₀H₂₂", visible: :all
    assert_selector "#host [aria-live=polite]", text: /décane, C₁₀H₂₂/, visible: :all
    inside = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('#host svg text')].every((t) => { const b = t.getBBox(); return b.x >= 0 && b.x + b.width <= 640 })
    JS
    assert inside, "le décane déborde des 640 unités"
  end

  test "the semi-developed propane is written as text" do
    mount(alkane(3, "semi_developed"))

    assert_selector "#host svg text", text: "CH₃–CH₂–CH₃", visible: :all
    assert_no_selector "#host svg [data-bond]", visible: :all
    assert_selector "#host svg text[data-name]", text: "propane", visible: :all
  end

  test "the raw propane is written as its formula" do
    mount(alkane(3, "raw"))

    assert_selector "#host svg text", text: "C₃H₈", minimum: 2, visible: :all
    assert_selector "#host svg text[data-name]", text: "propane", visible: :all
  end

  test "a custom water molecule is drawn" do
    mount(figure(params: { "mode" => "custom", "atoms" => atoms([ "O", 6, 4 ], [ "H", 3, 8 ], [ "H", 9, 8 ]),
                           "bonds" => [ [ "a0", "a1", 1 ], [ "a0", "a2", 1 ] ] }))

    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_selector "#host svg [data-atom=O]", count: 1, visible: :all
    assert_selector "#host svg [data-atom=H]", count: 2, visible: :all
    assert_selector "#host svg text[data-formula]", text: "H₂O", visible: :all
  end

  test "a double bond is drawn with two parallel strokes" do
    mount(figure(params: { "mode" => "custom", "atoms" => atoms([ "O", 1, 6 ], [ "C", 6, 6 ], [ "O", 11, 6 ]),
                           "bonds" => [ [ "a0", "a1", 2 ], [ "a1", "a2", 2 ] ] }))

    assert_selector "#host svg [data-bond='2']", count: 2, visible: :all
    assert_selector "#host svg [data-bond='2'] line", count: 4, visible: :all
    assert_selector "#host svg text[data-formula]", text: "CO₂", visible: :all
  end

  test "a carbon with five bonds shows the description alone" do
    custom = figure(params: { "mode" => "custom", "atoms" => atoms([ "C", 6, 6 ], [ "H", 2, 6 ], [ "H", 10, 6 ], [ "H", 6, 2 ], [ "O", 6, 10 ]),
                              "bonds" => [ [ "a0", "a1", 1 ], [ "a0", "a2", 1 ], [ "a0", "a3", 1 ], [ "a0", "a4", 1 ] ] })
    tamper(custom, "[&quot;a0&quot;,&quot;a4&quot;,1]", "[&quot;a0&quot;,&quot;a4&quot;,2]")

    assert_selector "#host [data-figure-state=error]", visible: :all
    assert_no_selector "#host svg"
  end

  test "a hydrogen with two bonds shows the description alone" do
    custom = figure(params: { "mode" => "custom", "atoms" => atoms([ "O", 6, 4 ], [ "H", 3, 8 ], [ "H", 9, 8 ]),
                              "bonds" => [ [ "a0", "a1", 1 ], [ "a0", "a2", 1 ] ] })
    tamper(custom, "[&quot;a0&quot;,&quot;a2&quot;,1]", "[&quot;a1&quot;,&quot;a2&quot;,1]")

    assert_selector "#host [data-figure-state=error]", visible: :all
    assert_no_selector "#host svg"
  end
end
