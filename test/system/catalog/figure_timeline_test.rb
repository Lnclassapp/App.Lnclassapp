require "application_system_test_case"

# Lot A du chantier contenus-3e-histoire-geographie (CA-4, CA-5, CA-6) : la frise `timeline` dans un navigateur réel.
# Le partial rendu par le serveur est injecté dans une page réelle, à 390 px de large (téléphone) ou à 1280 px.
class Catalog::FigureTimelineSystemTest < ApplicationSystemTestCase
  PARAMS = {
    "start" => 1880, "end" => 1960, "step" => 10, "unit" => "year",
    "periods" => [ { "from" => 1884, "to" => 1914, "label" => "Conquête coloniale" }, { "from" => 1939, "to" => 1945, "label" => "Guerre" } ],
    "events" => [ { "at" => 1893, "label" => "Colonie de Côte d'Ivoire" }, { "at" => 1904, "label" => "AOF" }, { "at" => 1946, "label" => "Abolition du travail forcé" },
                  { "at" => 1947, "label" => "Retour de la Haute-Volta" }, { "at" => 1958, "label" => "République" }, { "at" => 1960, "label" => "Indépendance" } ]
  }.freeze

  def figure(params: PARAMS, controls: [])
    Entities::Catalog::Figure.new(key: "frise-test", kind: "timeline", params:, controls:, description: Factories::RevisionSheet::FIGURE_DESCRIPTION)
  end

  def render_figure(figure = figure()) = ApplicationController.render(partial: "catalog/figures/figure", locals: { figure: })

  def mount(figure = figure(), width: 390, html: nil)
    visit new_session_path
    page.execute_script(<<~JS, html || render_figure(figure), width)
      document.getElementById("host")?.remove()
      const host = document.createElement("div")
      host.id = "host"
      host.style.width = arguments[1] + "px"
      host.innerHTML = arguments[0]
      document.body.prepend(host)
    JS
  end

  def end_slider = { "param" => "end", "min" => 1900, "max" => 2000, "step" => 10, "label" => "fin" }

  def start_slider = { "param" => "start", "min" => 1880, "max" => 1950, "step" => 10, "label" => "début" }

  def overlapping_label_pairs
    page.evaluate_script(<<~JS)
      (() => {
        const boxes = [...document.querySelectorAll("#host svg [data-event] text")].map((t) => t.getBoundingClientRect())
        const pairs = []
        boxes.forEach((a, i) => boxes.slice(i + 1).forEach((b, j) => {
          if (a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom) pairs.push([i, i + 1 + j])
        }))
        return pairs
      })()
    JS
  end

  [ 390, 1280 ].each do |width|
    test "a 1880-1960 timeline with 2 periods and 6 events is ready at #{width} px, without any overlapping event label" do
      mount(width:)

      assert_selector "#host [data-figure-state=ready]", visible: :all
      assert_selector "#host figcaption.sr-only", visible: :all
      assert_selector "#host svg [data-tick]", count: 9, visible: :all
      assert_selector "#host svg [data-event]", count: 6, visible: :all
      assert_selector "#host svg [data-period]", count: 2, visible: :all
      assert_empty overlapping_label_pairs
    end
  end

  test "the start slider raised to 1920 draws fewer ticks and hides the events before it" do
    mount(figure(controls: [ start_slider ]))
    assert_selector "#host svg [data-tick]", count: 9, visible: :all

    find("#host input[type=range]").set(1920)

    assert_selector "#host svg [data-tick]", count: 5, visible: :all
    assert_selector "#host svg [data-event]", count: 4, visible: :all
    assert_selector "#host svg [data-period]", count: 1, visible: :all
    assert_empty overlapping_label_pairs
  end

  test "the end slider lowered to 1920 draws fewer ticks and hides the events after it" do
    mount(figure(params: PARAMS.merge("end" => 2000, "events" => PARAMS["events"] + [ { "at" => 1990, "label" => "Fin de siècle" } ]), controls: [ end_slider ]))
    assert_selector "#host svg [data-tick]", count: 13, visible: :all
    assert_selector "#host svg [data-event]", count: 7, visible: :all

    find("#host input[type=range]").set(1920)

    assert_selector "#host svg [data-tick]", count: 5, visible: :all
    assert_selector "#host svg [data-event]", count: 2, visible: :all
    assert_selector "#host svg [data-period]", count: 1, visible: :all
    assert_empty overlapping_label_pairs
  end

  test "crowded long labels are replaced by numbers explained in a legend, without overlap" do
    events = (1940..1944).map { |year| { "at" => year, "label" => "Événement très long de l'année #{year}" } }
    mount(figure(params: PARAMS.merge("events" => events)))

    assert_selector "#host svg [data-event]", count: 5, visible: :all
    assert_selector "#host svg [data-legend] text", count: 5, visible: :all
    assert_equal %w[1 2 3 4 5], page.evaluate_script("[...document.querySelectorAll('#host svg [data-event] text')].map((t) => t.textContent)")
    assert_empty overlapping_label_pairs
  end

  test "a malformed timeline injected in the page shows the description alone" do
    mount(html: render_figure.sub("&quot;end&quot;:1960", "&quot;end&quot;:1800"))

    assert_selector "#host [data-figure-state=error]", visible: :all
    assert_no_selector "#host svg"
    assert_no_selector "#host figcaption.sr-only", visible: :all
    assert_text Factories::RevisionSheet::FIGURE_DESCRIPTION
  end

  test "a timeline in days writes the unit on its axis" do
    mount(figure(params: PARAMS.merge("unit" => "day", "start" => 0, "end" => 28, "step" => 7, "periods" => [], "events" => [])))

    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_selector "#host svg text", text: "jour", visible: :all
  end

  test "a year timeline writes no unit suffix" do
    mount

    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_no_selector "#host svg text", text: /\A(jour|mois)\z/, visible: :all
  end
end
