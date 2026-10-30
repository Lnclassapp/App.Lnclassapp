require "application_system_test_case"

# Tracé optique dans un navigateur : lentille mince (image calculée, curseur de distance) et œil réduit (défaut et correction).
# Le partial rendu par le serveur est injecté dans une page réelle, comme figure_kinds_test.
class Catalog::FigureOpticsSystemTest < ApplicationSystemTestCase
  def figure(params:, controls: [])
    Entities::Catalog::Figure.new(key: "figure-test", kind: "optics", params:, controls:,
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
      host.style.maxWidth = "600px"
      host.innerHTML = arguments[0]
      document.body.prepend(host)
    JS
  end

  def lens(kind: "convergent", focal: 4, distance: 12, height: 2, controls: [])
    figure(params: { "mode" => "lens", "lens" => kind, "focal" => focal, "object_distance" => distance, "object_height" => height }, controls:)
  end

  def eye(defect, correction = nil)
    params = { "mode" => "eye", "defect" => defect }
    params["correction"] = correction if correction
    figure(params:)
  end

  def distance_slider = { "param" => "object_distance", "min" => 1, "max" => 20, "step" => 1, "label" => "distance de l'objet" }

  def assert_measure(name, text) = assert_selector("#host svg [data-measure=#{name}]", text:, exact_text: true)

  test "a convergent lens forms a real, inverted, reduced image with three rays and both foci" do
    mount(lens)

    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_selector "#host svg [data-ray]", count: 3, visible: :all
    assert_selector "#host svg [data-focus=F]", count: 1, visible: :all
    assert_selector "#host svg [data-focus='F\\'']", count: 1, visible: :all
    assert_measure "oa", "OA' = 6 cm"
    assert_measure "gamma", "γ = −0,5"
    assert_measure "nature", "réelle, renversée, réduite"
    assert_selector "#host svg [data-image]", count: 1, visible: :all
    assert_no_selector "#host svg [data-image][data-virtual]", visible: :all
  end

  test "the object distance slider redraws a virtual image in dashes and announces it" do
    mount(lens(controls: [ distance_slider ]))
    assert_measure "oa", "OA' = 6 cm"

    find("input[type=range]").set(2)

    assert_measure "oa", "OA' = −4 cm"
    assert_measure "gamma", "γ = 2"
    assert_measure "nature", "virtuelle, droite, agrandie"
    assert_selector "#host svg [data-image][data-virtual]", count: 1, visible: :all
    dash = page.evaluate_script("document.querySelector('#host [data-image][data-virtual] [data-shaft]').getAttribute('stroke-dasharray')")
    assert_match(/\d/, dash.to_s)
    # Sans attendre : la mesure de la figure, pas le libellé du curseur, est ce que le relâchement vient d'annoncer.
    spoken = page.evaluate_script("document.querySelector('#host [aria-live=polite]').textContent")
    assert_match /OA' = −4 cm.*γ = 2.*virtuelle, droite, agrandie/, spoken
    assert_selector "#host svg [data-ray]", count: 3, visible: :all
  end

  test "an object at the focus gives an image at infinity and the figure stays ready" do
    mount(lens(distance: 4))

    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_measure "nature", "image à l'infini"
    assert_no_selector "#host svg [data-image]", visible: :all
    assert_selector "#host svg [data-ray]", count: 3, visible: :all
  end

  test "a divergent lens always gives a virtual, upright, reduced image" do
    mount(lens(kind: "divergent"))

    assert_measure "oa", "OA' = −3 cm"
    assert_measure "gamma", "γ = 0,25"
    assert_measure "nature", "virtuelle, droite, réduite"
    assert_selector "#host svg [data-image][data-virtual]", count: 1, visible: :all
  end

  test "at 390 px the object A, B and the image A', B' are labelled and none is cut off" do
    [ lens, lens(kind: "divergent", focal: 5, distance: 30), lens(focal: 10, distance: 60, height: 10), lens(kind: "divergent", focal: 20, distance: 1) ].each do |figure|
      mount(figure)
      page.execute_script("document.getElementById('host').style.maxWidth = '390px'; document.getElementById('host').style.width = '390px'")
      assert_selector "#host [data-figure-state=ready]", visible: :all

      names = page.evaluate_script("[...document.querySelectorAll('#host svg text')].map((t) => t.textContent)")
      assert_equal %w[A B], (names & %w[A B]).sort, "A et B sont écrits"
      assert_equal %w[A' B'], (names & %w[A' B']).sort, "A' et B' sont écrits"
      edges = page.evaluate_script(<<~JS)
        [...document.querySelectorAll("#host svg text")].filter((t) => ["A", "B", "A'", "B'"].includes(t.textContent)).map((t) => { const b = t.getBBox(); return [b.x, b.x + b.width] })
      JS
      assert(edges.all? { |left, right| left >= 24 && right <= 616 }, "une étiquette est trop près du bord : #{edges}")
    end
  end

  test "the figure keeps its markers and clip paths unique when two figures share the page" do
    mount_html(render_html(lens) + render_html(lens(kind: "divergent")))
    assert_selector "#host [data-figure-state=ready]", count: 2, visible: :all

    ids = page.evaluate_script("[...document.querySelectorAll('#host svg [id]')].map((n) => n.id)")
    assert_equal ids.uniq.size, ids.size
    assert_operator ids.size, :>=, 6
  end

  test "a myopic eye focuses before the retina, a diverging lens brings it back on the retina" do
    mount(eye("myopia"))
    assert_selector "#host svg[data-convergence=before]", visible: :all
    assert_selector "#host svg [data-ray]", count: 3, visible: :all
    assert_measure "convergence", "L'image se forme avant la rétine : œil myope"

    mount(eye("myopia", "divergent"))
    assert_selector "#host svg[data-convergence=on]", visible: :all
    assert_selector "#host svg [data-correction=divergent]", count: 1, visible: :all

    mount(eye("myopia", "convergent"))
    assert_selector "#host svg[data-convergence=before]", visible: :all
  end

  test "a hyperopic eye focuses after the retina, a converging lens brings it back on the retina" do
    mount(eye("hyperopia"))
    assert_selector "#host svg[data-convergence=after]", visible: :all

    mount(eye("hyperopia", "convergent"))
    assert_selector "#host svg[data-convergence=on]", visible: :all
    assert_measure "convergence", "L'image se forme sur la rétine : œil hypermétrope, lentille convergente"

    mount(eye("hyperopia", "divergent"))
    assert_selector "#host svg[data-convergence=after]", visible: :all
  end

  test "an unknown mode injected in the page shows the description alone and draws nothing" do
    mount_html(render_html(lens).sub("&quot;mode&quot;:&quot;lens&quot;", "&quot;mode&quot;:&quot;laser&quot;"))

    assert_selector "#host [data-figure-state=error]", visible: :all
    assert_no_selector "#host svg"
  end

  test "an object distance out of bounds injected in the page shows the description alone" do
    mount_html(render_html(lens).sub("&quot;object_distance&quot;:12", "&quot;object_distance&quot;:1e308"))

    assert_selector "#host [data-figure-state=error]", visible: :all
    assert_no_selector "#host svg"
  end
end
