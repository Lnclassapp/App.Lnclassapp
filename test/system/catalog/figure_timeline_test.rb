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
    mount(figure(params: PARAMS.merge("events" => events, "periods" => [])))

    assert_selector "#host svg [data-event]", count: 5, visible: :all
    assert_selector "#host svg [data-legend] text", count: 5, visible: :all
    assert_equal %w[1 2 3 4 5], page.evaluate_script("[...document.querySelectorAll('#host svg [data-event] text')].map((t) => t.textContent)")
    assert_empty overlapping_label_pairs
  end

  # La frise de la leçon sur l'ONU : « ONUCI en Côte d'Ivoire » ne tient pas dans sa bande étroite à 390 px.
  ONU = {
    "start" => 1940, "end" => 2020, "step" => 10, "unit" => "year",
    "periods" => [ { "from" => 1940, "to" => 1945, "label" => "Seconde Guerre mondiale (jusqu'en 1945)" }, { "from" => 2004, "to" => 2017, "label" => "ONUCI en Côte d'Ivoire" } ],
    "events" => [ { "at" => 1941, "label" => "Charte de l'Atlantique" }, { "at" => 1945, "label" => "Création de l'ONU" },
                  { "at" => 1948, "label" => "Déclaration universelle des droits de l'homme" }, { "at" => 1960, "label" => "La Côte d'Ivoire entre à l'ONU" },
                  { "at" => 1994, "label" => "Conseil de tutelle suspendu" }, { "at" => 2004, "label" => "Début de l'ONUCI" }, { "at" => 2017, "label" => "Fin de l'ONUCI" } ]
  }.freeze

  # Ce que la frise écrit : chaque texte dessiné (hors légende) et le texte de la légende numérotée.
  def drawn_and_legend
    page.evaluate_script(<<~JS)
      (() => ({
        drawn: [...document.querySelectorAll("#host svg text")].filter((t) => !t.closest("[data-legend]")).map((t) => t.textContent),
        legend: [...document.querySelectorAll("#host svg [data-legend] text")].map((t) => [...t.querySelectorAll("tspan")].map((line) => line.textContent).join(" "))
      }))()
    JS
  end

  # Un libellé de période ou d'événement visible entre `from` et la fin de la frise : dessiné en entier ou entier dans la légende.
  def assert_whole_timeline_labels(params, label, from: params["start"])
    found = drawn_and_legend
    periods = params["periods"].select { |period| period["to"] > from }
    events = params["events"].select { |event| event["at"] >= from }

    refute_includes (found["drawn"] + found["legend"]).join, "…", "#{label} : un libellé est tronqué"
    (periods + events).each do |item|
      assert(found["drawn"].include?(item["label"]) || found["legend"].any? { it.include?(item["label"]) },
             "#{label} : « #{item["label"]} » n'est ni dessiné ni dans la légende")
    end
  end

  test "the United Nations timeline on a phone truncates no period or event label, before and after moving the cursor" do
    mount(figure(params: ONU, controls: [ { "param" => "start", "min" => 1940, "max" => 1990, "step" => 10, "label" => "Début de la frise" } ]))

    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_whole_timeline_labels(ONU, "ONU à 390 px")
    assert_empty overlapping_label_pairs

    find("#host input[type=range]").set(1990)

    assert_selector "#host svg [data-tick]", count: 4, visible: :all
    assert_whole_timeline_labels(ONU, "ONU à 390 px, curseur à 1990", from: 1990)
    assert_equal 1, page.evaluate_script("document.querySelectorAll('#host svg [data-period]').length")
    assert_selector "#host svg [data-period][data-note]", visible: :all
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
