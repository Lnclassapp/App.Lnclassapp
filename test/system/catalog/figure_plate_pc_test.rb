require "application_system_test_case"

# CA « Planches de Physique-Chimie » dans un navigateur : le dynamomètre, l'électrolyseur et l'eudiomètre se dessinent (ready), chaque étiquette
# relie sa partie, `numbers` n'écrit que des numéros attribués dans l'ordre de `labels`, et à 390 px aucune étiquette ne déborde ni ne se chevauche.
class Catalog::FigurePlatePcSystemTest < ApplicationSystemTestCase
  PLATES = Entities::Catalog::FigureCatalogs::PLATES.slice("dynamometer", "electrolyser", "eudiometer")
  NAMES = {
    "dynamometer" => [ "anneau", "tube", "ressort", "graduation (en N)", "index", "crochet", "corps suspendu" ],
    "electrolyser" => [ "générateur", "cuve", "eau additionnée de soude", "anode (reliée au +)", "cathode (reliée au −)", "tube de dioxygène",
                        "tube de dihydrogène", "dioxygène", "dihydrogène" ],
    "eudiometer" => [ "tube gradué", "graduation", "électrodes", "étincelle", "mélange de dihydrogène et de dioxygène", "eau", "cuve à eau" ]
  }.freeze

  def figure(params)
    Entities::Catalog::Figure.new(key: "figure-test", kind: "plate", params:, controls: [],
                                  description: Factories::RevisionSheet::FIGURE_DESCRIPTION)
  end

  def html(params) = ApplicationController.render(partial: "catalog/figures/figure", locals: { figure: figure(params) })

  # Une seule visite par test : les montages suivants remplacent l'hôte dans la même page.
  def mount_html(markup)
    visit new_session_path unless page.has_css?("body > *", wait: 0)
    page.execute_script(<<~JS, markup)
      document.getElementById("host")?.remove()
      const host = document.createElement("div")
      host.id = "host"
      host.innerHTML = arguments[0]
      document.body.prepend(host)
    JS
  end

  def params_for(plate, parts: PLATES.fetch(plate), numbering: "names", highlight: [])
    { "plate" => plate, "numbering" => numbering, "highlight" => highlight, "labels" => parts.map { { "part" => it } } }
  end

  def labels = page.evaluate_script("[...document.querySelectorAll('#host svg [data-label]')].map((node) => [node.dataset.label, [...node.querySelectorAll('text')].map((line) => line.textContent.trim()).join(' ')])")

  PLATES.each do |plate, parts|
    test "the #{plate} plate is ready, draws every part and ends the leader line of every label on its part" do
      mount_html(html(params_for(plate)))

      assert_selector "#host [data-figure-state=ready]", visible: :all
      assert_selector "#host figcaption.sr-only", text: Factories::RevisionSheet::FIGURE_DESCRIPTION, visible: :all
      assert_selector "#host svg [data-plate=#{plate}]", visible: :all
      assert_equal parts.sort, labels.map(&:first).sort
      assert_equal NAMES.fetch(plate).sort, labels.map(&:last).sort
      assert_selector "#host svg [data-label] line", count: parts.size, visible: :all
      parts.each { assert_selector "#host svg [data-plate=#{plate}] [data-part=#{it}]", visible: :all }

      ends = page.evaluate_script(<<~JS)
        [...document.querySelectorAll("#host svg [data-label]")].map((label) => {
          const line = label.querySelector("line")
          const boxes = [...document.querySelectorAll(`#host svg [data-part=${label.dataset.label}]`)].map((part) => {
            const box = part.getBBox()
            return { left: box.x, right: box.x + box.width, top: box.y, bottom: box.y + box.height }
          })
          return { name: label.dataset.label, x: Number(line.getAttribute("x2")), y: Number(line.getAttribute("y2")), boxes }
        })
      JS
      assert_equal parts.size, ends.size
      ends.each do |e|
        # Une partie peut avoir plusieurs formes (l'eau de la cuve et celle du tube) : le trait doit finir sur l'une d'elles.
        on_part = e["boxes"].any? { |b| e["x"] >= b["left"] - 4 && e["x"] <= b["right"] + 4 && e["y"] >= b["top"] - 4 && e["y"] <= b["bottom"] + 4 }
        assert on_part,
               "#{plate} : le trait de #{e['name']} finit hors de sa partie : #{e}"
      end
    end

    test "the #{plate} plate highlights each of its parts" do
      parts.each_slice(4) do |slice|
        mount_html(html(params_for(plate, parts: [ slice.first ], highlight: slice)))

        assert_selector "#host [data-figure-state=ready]", visible: :all
        slice.each { assert_selector "#host svg [data-part=#{it}][data-highlight]", visible: :all }
      end
    end

    test "the #{plate} plate in numbers shows only numbers, attributed in the order of labels" do
      shuffled = parts.reverse
      mount_html(html(params_for(plate, parts: shuffled, numbering: "numbers")))

      assert_selector "#host [data-figure-state=ready]", visible: :all
      assert_equal shuffled.each_with_index.map { |part, index| [ part, (index + 1).to_s ] }.sort, labels.sort
      NAMES.fetch(plate).each { assert_no_selector "#host svg text", text: it, exact_text: true, visible: :all }
    end

    test "at 390 px no label of the #{plate} plate overflows or overlaps another" do
      [ "names", "numbers" ].each do |numbering|
        mount_html(html(params_for(plate, numbering:)))
        page.execute_script("const h = document.getElementById('host'); h.style.maxWidth = '390px'; h.style.width = '390px'")
        assert_selector "#host [data-figure-state=ready]", visible: :all

        boxes = page.evaluate_script(<<~JS)
          (() => {
            const rect = (n) => { const b = n.getBoundingClientRect(); return { name: n.dataset.label, left: b.left, right: b.right, top: b.top, bottom: b.bottom } }
            const svg = document.querySelector("#host svg")
            const frame = svg.getBoundingClientRect()
            return { frame: { left: frame.left, right: frame.right, top: frame.top, bottom: frame.bottom },
                     texts: [...svg.querySelectorAll("[data-label]")].map((g) => { const b = g.querySelectorAll("text"); const r = [...b].map((t) => t.getBoundingClientRect()); return { name: g.dataset.label, left: Math.min(...r.map((x) => x.left)), right: Math.max(...r.map((x) => x.right)), top: Math.min(...r.map((x) => x.top)), bottom: Math.max(...r.map((x) => x.bottom)) } }) }
          })()
        JS
        frame = boxes["frame"]
        texts = boxes["texts"]
        assert_equal PLATES.fetch(plate).size, texts.size
        texts.each do |b|
          assert b["left"] >= frame["left"] - 0.5 && b["right"] <= frame["right"] + 0.5 && b["top"] >= frame["top"] - 0.5 && b["bottom"] <= frame["bottom"] + 0.5,
                 "#{plate} (#{numbering}) : #{b['name']} sort du cadre : #{b} / #{frame}"
        end
        texts.combination(2).each do |a, b|
          apart = a["right"] <= b["left"] || b["right"] <= a["left"] || a["bottom"] <= b["top"] || b["bottom"] <= a["top"]
          assert apart, "#{plate} (#{numbering}) : #{a['name']} et #{b['name']} se chevauchent (#{a} / #{b})"
        end
      end
    end
  end

  test "the electrolyser draws twice as much dihydrogen as dioxygen" do
    mount_html(html(params_for("electrolyser")))

    assert_selector "#host [data-figure-state=ready]", visible: :all
    heights = page.evaluate_script("['oxygen', 'hydrogen'].map((id) => document.querySelector(`#host svg [data-part=${id}]`).getBBox().height)")
    assert_in_delta 2.0, heights.last / heights.first, 0.05
  end
end
