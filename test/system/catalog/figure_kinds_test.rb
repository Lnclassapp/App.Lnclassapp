require "application_system_test_case"

# CA-13 dans un navigateur : les sortes coordinate_plane, stat_chart et solid réagissent à leurs curseurs.
# Le partial rendu par le serveur est injecté dans une page réelle (aucune page de leçon v3 n'est nécessaire).
class Catalog::FigureKindsSystemTest < ApplicationSystemTestCase
  def figure(kind:, params:, controls: [])
    Entities::Catalog::Figure.new(key: "figure-test", kind:, params:, controls:,
                                  description: Factories::RevisionSheet::FIGURE_DESCRIPTION)
  end

  def mount(figure)
    html = ApplicationController.render(partial: "catalog/figures/figure", locals: { figure: })
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

  def slider(param, min, max, label) = { "param" => param, "min" => min, "max" => max, "step" => 1, "label" => label }

  test "a coordinate plane draws a vector and its slider changes the visible window" do
    params = { "xmin" => -5, "xmax" => 5, "ymin" => -5, "ymax" => 5,
               "points" => [ { "id" => "A", "x" => 1, "y" => 1 } ],
               "vectors" => [ { "label" => "u", "dx" => 3, "dy" => 2, "ox" => 0, "oy" => 0 } ],
               "lines" => [ { "a" => 1, "b" => 0 } ], "segments" => [ { "x1" => -2, "y1" => -2, "x2" => 2, "y2" => -1 } ] }
    mount(figure(kind: "coordinate_plane", params:, controls: [ slider("xmax", 5, 10, "abscisse maximale") ]))

    assert_selector "#host svg [data-vector]", count: 1, visible: :all
    assert_selector "#host svg text", text: /u\s*\(3 ; 2\)/
    assert_selector "#host svg [data-xtick]", count: 11, visible: :all
    find("input[type=range]").set(9)

    assert_selector "#host svg [data-xtick]", count: 7, visible: :all
    assert_selector "#host svg [data-vector]", count: 1, visible: :all
  end

  test "a bar chart draws one bar per value, proportional to it" do
    mount(figure(kind: "stat_chart", params: { "chart" => "bars", "series" => [ 4, 8, 2 ], "labels" => %w[a b c] }))

    assert_selector "#host svg [data-bar]", count: 3, visible: :all
    heights = page.evaluate_script("[...document.querySelectorAll('#host [data-bar]')].map((n) => Number(n.getAttribute('height')))")

    assert_in_delta heights[1], 2 * heights[0], 0.1
    assert_in_delta heights[2], heights[0] / 2, 0.1
  end

  test "a histogram has bars side by side" do
    mount(figure(kind: "stat_chart", params: { "chart" => "histogram", "series" => [ 3, 6, 4 ], "labels" => %w[0-5 5-10 10-15] }))

    assert_selector "#host svg [data-bar]", count: 3, visible: :all
    xs = page.evaluate_script("[...document.querySelectorAll('#host [data-bar]')].map((n) => [Number(n.getAttribute('x')), Number(n.getAttribute('width'))])")

    assert_equal 3, xs.size
    assert_in_delta xs[0][0] + xs[0][1], xs[1][0], 0.1
    assert_in_delta xs[1][0] + xs[1][1], xs[2][0], 0.1
  end

  test "a pie chart draws one slice per value with its share" do
    mount(figure(kind: "stat_chart", params: { "chart" => "pie", "series" => [ 50, 30, 20 ], "labels" => %w[a b c] }))

    assert_selector "#host svg [data-slice]", count: 3, visible: :all
    assert_selector "#host svg text", text: /50 %/
    assert_selector "#host svg text", text: /20 %/
  end

  test "a negative value in a chart shows the description, not a broken drawing" do
    mount(figure(kind: "stat_chart", params: { "chart" => "pie", "series" => [ 5, -1 ], "labels" => %w[a b] }))

    assert_selector "figcaption", text: Factories::RevisionSheet::FIGURE_DESCRIPTION
    assert_no_selector "#host svg [data-slice]", visible: :all
  end

  test "a square pyramid shows five visible and three hidden edges and its volume follows the height slider" do
    params = { "shape" => "pyramid", "base" => "square", "side" => 4, "height" => 6 }
    mount(figure(kind: "solid", params:, controls: [ slider("height", 3, 12, "hauteur") ]))

    assert_selector "#host svg [data-edge='visible']", count: 5, visible: :all
    assert_selector "#host svg [data-edge='hidden']", count: 3, visible: :all
    assert_selector "#host svg text", text: /V ≈ 32,0/
    find("input[type=range]").set(9)

    assert_selector "#host svg text", text: /V ≈ 48,0/
  end

  test "a pyramid keeps a fixed scale so the height slider visibly grows it on screen" do
    params = { "shape" => "pyramid", "base" => "square", "side" => 4, "height" => 6 }
    mount(figure(kind: "solid", params:, controls: [ slider("height", 3, 12, "hauteur") ]))
    on_screen = "document.querySelector('#host svg [data-height]').getBoundingClientRect().height"

    assert_selector "#host svg [data-height]", visible: :all
    find("input[type=range]").set(3)
    assert_selector "#host svg text", text: /V ≈ 16,0/
    low = page.evaluate_script(on_screen)
    find("input[type=range]").set(12)
    assert_selector "#host svg text", text: /V ≈ 64,0/
    high = page.evaluate_script(on_screen)

    assert_operator high, :>, low * 2.5
  end

  test "a triangular pyramid has a single hidden edge and a rectangular one uses width and depth" do
    mount(figure(kind: "solid", params: { "shape" => "pyramid", "base" => "triangular", "side" => 4, "height" => 5 }))

    assert_selector "#host svg [data-edge='hidden']", count: 1, visible: :all
    assert_selector "#host svg [data-edge]", count: 6, visible: :all

    mount(figure(kind: "solid", params: { "shape" => "pyramid", "base" => "rectangular", "width" => 4, "depth" => 3, "height" => 5 },
                 controls: [ slider("depth", 2, 8, "profondeur") ]))

    assert_selector "#host svg text", text: /V ≈ 20,0/
    find("input[type=range]").set(6)

    assert_selector "#host svg text", text: /V ≈ 40,0/
  end

  test "a cone has a hidden half base and its volume follows the radius slider" do
    mount(figure(kind: "solid", params: { "shape" => "cone", "radius" => 3, "height" => 4 }, controls: [ slider("radius", 2, 6, "rayon") ]))

    assert_selector "#host svg [data-edge='hidden']", count: 1, visible: :all
    assert_selector "#host svg text", text: /V ≈ 37,7/
    find("input[type=range]").set(5)

    assert_selector "#host svg text", text: /V ≈ 104,7/
  end

  test "a solid with a missing dimension shows the description only" do
    mount(figure(kind: "solid", params: { "shape" => "cone", "radius" => 3 }))

    assert_selector "figcaption", text: Factories::RevisionSheet::FIGURE_DESCRIPTION
    assert_no_selector "#host svg [data-edge]", visible: :all
  end
end
