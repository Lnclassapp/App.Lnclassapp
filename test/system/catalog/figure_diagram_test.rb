require "application_system_test_case"

# CA-4 et CA-6 dans un navigateur : le schéma fléché (diagram) en flow, tree et cycle, à 390 px et à 1280 px.
# Le partial rendu par le serveur est injecté dans une page réelle, comme dans figure_kinds_test.
class Catalog::FigureDiagramSystemTest < ApplicationSystemTestCase
  DESKTOP = [ 1280, 900 ].freeze

  ONU = {
    "layout" => "tree",
    "nodes" => [ { "id" => "onu", "label" => "ONU" },
                 { "id" => "ag", "label" => "Assemblée générale" },
                 { "id" => "cs", "label" => "Conseil de sécurité" },
                 { "id" => "sec", "label" => "Secrétariat" },
                 { "id" => "cij", "label" => "Cour internationale de justice" },
                 { "id" => "ecosoc", "label" => "Conseil économique et social" },
                 { "id" => "tut", "label" => "Conseil de tutelle" } ],
    "edges" => %w[ag cs sec cij ecosoc tut].map { |to| { "from" => "onu", "to" => to } }
  }.freeze

  def figure(params:)
    Entities::Catalog::Figure.new(key: "figure-test", kind: "diagram", params:, controls: [],
                                  description: Factories::RevisionSheet::FIGURE_DESCRIPTION)
  end

  def mount(params = nil, copies: 1, **options)
    params ||= options.transform_keys(&:to_s)
    html = ApplicationController.render(partial: "catalog/figures/figure", locals: { figure: figure(params:) })
    visit new_session_path
    page.execute_script(<<~JS, html, copies)
      document.getElementById("host")?.remove()
      const host = document.createElement("div")
      host.id = "host"
      host.innerHTML = arguments[0].repeat(arguments[1])
      document.body.prepend(host)
    JS
  end

  def chain(count, layout: "flow", direction: "right")
    ids = (1..count).map { "n#{it}" }
    { "layout" => layout, "direction" => direction,
      "nodes" => ids.each_with_index.map { |id, index| { "id" => id, "label" => "Étape #{index + 1}" } },
      "edges" => ids.each_cons(2).map { |from, to| { "from" => from, "to" => to } } }
  end

  # Pairs of node boxes that intersect, and nodes whose text leaves their box (in screen pixels).
  def collisions
    page.evaluate_script(<<~JS)
      (() => {
        const boxes = [...document.querySelectorAll("#host [data-node]")].map((node) => ({
          id: node.dataset.node, box: node.querySelector("rect[data-box]").getBoundingClientRect(),
          texts: [...node.querySelectorAll("text")].map((text) => text.getBoundingClientRect())
        }))
        const overlap = (a, b) => a.left < b.right - 0.5 && b.left < a.right - 0.5 && a.top < b.bottom - 0.5 && b.top < a.bottom - 0.5
        const crossed = []
        boxes.forEach((a, i) => boxes.slice(i + 1).forEach((b) => { if (overlap(a.box, b.box)) crossed.push([a.id, b.id]) }))
        const spilled = boxes.filter(({ box, texts }) => texts.some((t) => t.left < box.left - 1 || t.right > box.right + 1 || t.top < box.top - 1 || t.bottom > box.bottom + 1)).map((n) => n.id)
        return { crossed, spilled }
      })()
    JS
  end

  def viewbox
    box = page.evaluate_script("document.querySelector('#host svg').viewBox.baseVal")
    [ box["width"], box["height"] ]
  end

  def each_viewport
    page.current_window.resize_to(*DESKTOP)
    yield "1280 px"
    with_mobile_viewport { yield "390 px" }
  end

  def assert_laid_out(nodes:, edges:, label:)
    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_selector "#host svg [data-node]", count: nodes, visible: :all
    assert_selector "#host svg [data-edge]", count: edges, visible: :all
    found = collisions

    assert_empty found["crossed"], "#{label} : nœuds qui se chevauchent"
    assert_empty found["spilled"], "#{label} : texte qui déborde de son nœud"
    width, height = viewbox

    assert_equal 640, width
    assert_operator height, :<=, 640
  end

  test "a flow of five nodes going right is ready and its boxes do not overlap" do
    params = chain(5, direction: "right")
    each_viewport do |size|
      mount(params)
      assert_laid_out(nodes: 5, edges: 4, label: "flow right à #{size}")
    end
  end

  test "a flow of five nodes going down is a single column in order" do
    each_viewport do |size|
      mount(chain(5, direction: "down"))
      assert_laid_out(nodes: 5, edges: 4, label: "flow down à #{size}")
      tops = page.evaluate_script("[...document.querySelectorAll('#host [data-node] rect[data-box]')].map((n) => n.getBoundingClientRect().top)")

      assert_equal tops.sort, tops
      assert_equal 5, tops.uniq.size
    end
  end

  test "the organs of the UN form a tree of seven nodes with the root first" do
    each_viewport do |size|
      mount(ONU)
      assert_laid_out(nodes: 7, edges: 6, label: "tree à #{size}")
      root = page.evaluate_script("document.querySelector('#host [data-node=onu] rect[data-box]').getBoundingClientRect().top")
      others = page.evaluate_script("[...document.querySelectorAll('#host [data-node]:not([data-node=onu]) rect[data-box]')].map((n) => n.getBoundingClientRect().top)")

      assert_operator root, :<, others.min
    end
  end

  test "a cycle of four nodes is ready and its boxes do not overlap" do
    params = { "layout" => "cycle",
               "nodes" => %w[a b c d].each_with_index.map { |id, index| { "id" => id, "label" => "Phase #{index + 1}" } },
               "edges" => [ %w[a b], %w[b c], %w[c d], %w[d a] ].map { |from, to| { "from" => from, "to" => to } } }
    each_viewport do |size|
      mount(params)
      assert_laid_out(nodes: 4, edges: 4, label: "cycle à #{size}")
    end
  end

  test "a label that is too long is cut with an ellipsis and its full text is kept in a title" do
    full = "Conférence de Berlin sur le partage colonial de l'Afrique centrale et occidentale en 1885"
    mount("layout" => "flow", "nodes" => [ { "id" => "a", "label" => full }, { "id" => "b", "label" => "Fin" } ],
          "edges" => [ { "from" => "a", "to" => "b" } ])

    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_selector "#host [data-node=a] text", text: /…/, visible: :all
    assert_equal full, page.evaluate_script("document.querySelector('#host [data-node=a] title').textContent")
    assert_no_selector "#host [data-node=b] title", visible: :all
    assert_empty collisions["spilled"]
  end

  test "category 4 is filled with its hatch pattern and the legend is drawn" do
    mount("layout" => "flow", "legend" => %w[Causes Effets Acteurs Lieux],
          "nodes" => [ { "id" => "a", "label" => "Cause", "category" => 1 }, { "id" => "b", "label" => "Lieu", "category" => 4 } ],
          "edges" => [ { "from" => "a", "to" => "b", "label" => "mène à" } ])

    assert_selector "#host [data-figure-state=ready]", visible: :all
    pattern = page.evaluate_script("document.querySelector('#host svg pattern[id$=\"-pat-4\"]')?.id")

    assert_match(/\Afig-[\w-]+-pat-4\z/, pattern)
    assert page.evaluate_script("[...document.querySelectorAll('#host [data-node=b] rect')].some((r) => r.style.fill.includes('#{pattern}'))")
    assert_selector "#host svg [data-legend]", count: 4, visible: :all
    assert_selector "#host svg [data-legend] text", text: "Lieux", visible: :all
    assert_selector "#host svg text", text: "mène à", visible: :all
  end

  test "two diagrams on one page have markers with distinct ids" do
    mount(chain(3), copies: 2)
    assert_selector "svg marker", count: 2, visible: :all
    ids = page.evaluate_script("[...document.querySelectorAll('svg marker')].map((m) => m.id)")

    assert_equal ids.uniq, ids
  end

  test "an edge towards a missing node shows the description alone" do
    params = chain(3, direction: "down")
    params["edges"] << { "from" => "n1", "to" => "absent" }
    mount(params)

    assert_selector "#host [data-figure-state=error]", visible: :all
    assert_no_selector "#host svg", visible: :all
    assert_selector "figcaption", text: Factories::RevisionSheet::FIGURE_DESCRIPTION
  end
end
