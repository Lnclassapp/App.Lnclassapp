require "application_system_test_case"

# CA-4, CA-6, CA-8 dans un navigateur : la sorte `map` dessine ses trois fonds, refuse ce que son fond ne connaît pas, distingue les
# catégories par teinte ET motif, et numérote les étiquettes qui se chevaucheraient à 390 px. Le partial rendu par le serveur est injecté
# dans une page réelle ; les valeurs sont modifiées après coup dans le HTML, comme le ferait une page corrompue.
class Catalog::FigureMapSystemTest < ApplicationSystemTestCase
  LEGEND = [ "Zone un", "Zone deux", "Zone trois", "Zone quatre hachurée" ].freeze

  def figure(params)
    Entities::Catalog::Figure.new(key: "figure-test", kind: "map", params:, controls: [],
                                  description: Factories::RevisionSheet::FIGURE_DESCRIPTION)
  end

  def html(figure) = ApplicationController.render(partial: "catalog/figures/figure", locals: { figure: })

  def mount_html(markup, width: 600)
    visit new_session_path
    page.execute_script(<<~JS, markup, width)
      document.getElementById("host")?.remove()
      const host = document.createElement("div")
      host.id = "host"
      host.style.maxWidth = `${arguments[1]}px`
      host.innerHTML = arguments[0]
      document.body.prepend(host)
    JS
  end

  def mount(params, width: 600) = mount_html(html(figure(params)), width:)

  def pattern_id = page.evaluate_script("document.querySelector('#host pattern[id$=\"-pat-4\"]')?.id")

  test "a Côte d'Ivoire map draws districts, zones, places, a route and a legend with tint and pattern" do
    mount({ "base" => "cote_d_ivoire",
            "areas" => [ { "id" => "savanes", "category" => 1 }, { "id" => "dense_forest", "category" => 2 }, { "id" => "coastal_strip", "category" => 4 } ],
            "places" => [ { "id" => "abidjan" }, { "id" => "korhogo", "label" => "Korhogo (Nord)" } ],
            "routes" => [ { "from" => "abidjan", "to" => "korhogo" } ], "legend" => LEGEND })

    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_selector "#host figcaption.sr-only", visible: :all
    assert_selector "#host svg [data-area]", count: 3, visible: :all
    assert_selector "#host svg [data-area=savanes][data-category='1']", visible: :all
    assert_selector "#host svg [data-place]", count: 2, visible: :all
    assert_selector "#host svg [data-route='abidjan>korhogo']", visible: :all
    assert_selector "#host svg [data-legend]", count: 4, visible: :all
    assert_selector "#host svg text", text: "Korhogo (Nord)"
    assert_selector "#host svg text", text: "Zone quatre hachurée"
    assert_selector "#host svg [data-attribution]", text: "Districts : geoBoundaries, CC BY 4.0"

    pattern = pattern_id
    assert_match(/\Afig-map\d+-pat-4\z/, pattern)
    assert_selector "#host svg [data-area=coastal_strip]", visible: :all
    assert_equal "url(##{pattern})", page.evaluate_script("document.querySelector('#host [data-area=coastal_strip]').getAttribute('fill')")
    assert_equal "url(##{pattern})", page.evaluate_script("document.querySelector('#host [data-legend=\"4\"] rect').getAttribute('fill')")
    assert_equal "0.35", page.evaluate_script("document.querySelector('#host [data-area=savanes]').getAttribute('fill-opacity')")
    assert_equal "0.35", page.evaluate_script("document.querySelector('#host [data-legend=\"1\"] rect').getAttribute('fill-opacity')")
    assert_equal 1, page.evaluate_script("document.querySelectorAll('#host marker').length")
  end

  test "three categories get three distinct tints, areas and legend alike" do
    mount({ "base" => "cote_d_ivoire", "legend" => LEGEND.first(3),
            "areas" => [ { "id" => "savanes", "category" => 1 }, { "id" => "dense_forest", "category" => 2 }, { "id" => "coastal_strip", "category" => 3 } ] })

    assert_selector "#host [data-figure-state=ready]", visible: :all
    tints = page.evaluate_script("[...document.querySelectorAll('#host [data-area]')].map((n) => getComputedStyle(n).fill)")
    swatches = page.evaluate_script("[...document.querySelectorAll('#host [data-legend] rect')].map((n) => getComputedStyle(n).fill)")

    assert_equal 3, tints.uniq.size
    assert_equal tints.sort, swatches.sort
  end

  test "categories 4 to 6 are filled with their own pattern, areas and legend alike" do
    mount({ "base" => "cote_d_ivoire", "legend" => %w[Un Deux Trois Quatre Cinq Six],
            "areas" => [ { "id" => "savanes", "category" => 4 }, { "id" => "dense_forest", "category" => 5 }, { "id" => "coastal_strip", "category" => 6 } ] })

    assert_selector "#host [data-figure-state=ready]", visible: :all
    [ 4, 5, 6 ].each do |category|
      id = page.evaluate_script("document.querySelector('#host pattern[id$=\"-pat-#{category}\"]')?.id")

      assert_match(/\Afig-map\d+-pat-#{category}\z/, id)
      assert_equal "url(##{id})", page.evaluate_script("document.querySelector('#host [data-area][data-category=\"#{category}\"]').getAttribute('fill')")
      assert_equal "url(##{id})", page.evaluate_script("document.querySelector('#host [data-legend=\"#{category}\"] rect').getAttribute('fill')")
    end
  end

  test "an Africa map draws States and capitals and shows no attribution" do
    mount({ "base" => "africa",
            "areas" => [ { "id" => "civ", "category" => 1 }, { "id" => "gha", "category" => 2 }, { "id" => "bfa", "category" => 5 } ],
            "places" => [ { "id" => "yamoussoukro" }, { "id" => "accra" }, { "id" => "ouagadougou" } ],
            "routes" => [ { "from" => "ouagadougou", "to" => "accra", "label" => "migration" } ],
            "legend" => [ "Côte d'Ivoire", "Ghana", "Burkina Faso", "Autre", "Pays voisin" ] })

    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_selector "#host svg [data-area]", count: 3, visible: :all
    assert_selector "#host svg [data-place]", count: 3, visible: :all
    assert_selector "#host svg [data-route]", count: 1, visible: :all
    assert_selector "#host svg [data-legend]", count: 5, visible: :all
    assert_no_selector "#host svg [data-attribution]", visible: :all
    assert_equal 1, page.evaluate_script("document.querySelectorAll('#host pattern[id$=\"-pat-5\"]').length")
    assert_equal 1, page.evaluate_script("document.querySelectorAll('#host pattern[id$=\"-pat-4\"]').length")
    assert_equal 0, page.evaluate_script("document.querySelectorAll('#host pattern[id$=\"-pat-6\"]').length"), "pas de motif pour une catégorie hors légende"
  end

  test "a world map colours a whole continent and draws places of the Second World War" do
    mount({ "base" => "world",
            "areas" => [ { "id" => "africa", "category" => 1 }, { "id" => "usa", "category" => 2 }, { "id" => "deu", "category" => 4 } ],
            "places" => [ { "id" => "pearl_harbor" }, { "id" => "hiroshima" } ],
            "routes" => [ { "from" => "pearl_harbor", "to" => "hiroshima" } ], "legend" => LEGEND })

    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_selector "#host svg [data-area]", count: 3, visible: :all
    assert_operator page.evaluate_script("document.querySelectorAll('#host g[data-area=africa] path').length"), :>=, 40
    assert_selector "#host svg [data-place]", count: 2, visible: :all
    assert_selector "#host svg [data-legend='4'] rect", visible: :all
    assert_equal 640, page.evaluate_script("document.querySelector('#host svg').viewBox.baseVal.width")
    assert_operator page.evaluate_script("document.querySelector('#host svg').viewBox.baseVal.height"), :>, 360, "la légende est dessinée sous le fond de 640×360"
  end

  test "two maps on one page keep their own patterns" do
    params = { "base" => "africa", "areas" => [ { "id" => "civ", "category" => 4 } ], "legend" => LEGEND }
    mount_html(html(figure(params)) + html(figure(params)))

    assert_selector "#host [data-figure-state=ready]", count: 2, visible: :all
    ids = page.evaluate_script("[...document.querySelectorAll('#host pattern[id$=\"-pat-4\"]')].map((node) => node.id)")
    assert_equal 2, ids.uniq.size
  end

  # Les valeurs sont posées dans le HTML après coup : l'entité Figure refuserait un lieu ou un fond inconnu, la page peut recevoir n'importe quoi.
  def assert_error_with_description(markup)
    mount_html(markup)

    assert_selector "#host [data-figure-state=error]", visible: :all
    assert_no_selector "#host svg"
    assert_selector "#host figcaption", text: Factories::RevisionSheet::FIGURE_DESCRIPTION
    assert_no_selector "#host figcaption.sr-only", visible: :all
  end

  test "a place unknown to its base shows the description alone" do
    params = { "base" => "cote_d_ivoire", "places" => [ { "id" => "abidjan" } ] }

    assert_error_with_description(html(figure(params)).sub("&quot;abidjan&quot;", "&quot;gotham_city&quot;"))
  end

  test "a place of another base shows the description alone" do
    params = { "base" => "cote_d_ivoire", "places" => [ { "id" => "abidjan" } ] }

    assert_error_with_description(html(figure(params)).sub("&quot;abidjan&quot;", "&quot;hiroshima&quot;"))
  end

  test "an unknown base is never imported and shows the description alone" do
    params = { "base" => "africa", "places" => [ { "id" => "abidjan" } ] }

    assert_error_with_description(html(figure(params)).sub("&quot;africa&quot;", "&quot;..\\/..\\/controllers\\/figure_controller&quot;"))
    assert_error_with_description(html(figure(params)).sub("&quot;africa&quot;", "&quot;mars&quot;"))
  end

  test "an unknown area, a category beyond the legend and a route to a missing place show the description alone" do
    params = { "base" => "africa", "areas" => [ { "id" => "civ", "category" => 1 } ], "legend" => [ "Un" ] }
    assert_error_with_description(html(figure(params)).sub("&quot;civ&quot;", "&quot;atlantis&quot;"))
    assert_error_with_description(html(figure(params)).sub("&quot;category&quot;:1", "&quot;category&quot;:2"))

    route = { "base" => "africa", "routes" => [ { "from" => "abidjan", "to" => "accra" } ] }
    assert_error_with_description(html(figure(route)).sub("&quot;accra&quot;", "&quot;nulle_part&quot;"))
  end

  test "close places on a phone get numbers explained in the legend, and no label overlaps another or a point" do
    mount({ "base" => "cote_d_ivoire",
            "places" => [ { "id" => "abidjan" }, { "id" => "bingerville" }, { "id" => "grand_bassam" }, { "id" => "dabou" } ] }, width: 390)

    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_selector "#host [data-figure-target=canvas][style*='--figure-text: 1.40']", visible: :all
    assert_selector "#host svg [data-legend-note]", minimum: 1, visible: :all
    notes = page.evaluate_script("document.querySelectorAll('#host svg [data-legend-note]').length")
    assert_equal notes, page.evaluate_script("document.querySelectorAll('#host svg text[data-note]').length"), "chaque numéro posé renvoie à une ligne de légende"

    boxes = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('#host svg [data-place-label]')].map((node) => {
        const box = node.getBoundingClientRect()
        return [box.left, box.top, box.right, box.bottom]
      })
    JS
    dots = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('#host svg [data-place]')].map((node) => {
        const box = node.getBoundingClientRect()
        return [(box.left + box.right) / 2, (box.top + box.bottom) / 2]
      })
    JS
    assert_equal 4, boxes.size
    boxes.combination(2).each do |a, b|
      assert(a[2] <= b[0] || b[2] <= a[0] || a[3] <= b[1] || b[3] <= a[1], "deux étiquettes se chevauchent : #{a.inspect} et #{b.inspect}")
    end
    boxes.product(dots).each do |box, (x, y)|
      assert(x < box[0] || x > box[2] || y < box[1] || y > box[3], "une étiquette recouvre un point : #{box.inspect} #{[ x, y ].inspect}")
    end
  end
end
