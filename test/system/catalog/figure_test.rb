require "application_system_test_case"

# CA-13 dans un navigateur : la figure paramétrée du partial catalog/figures/_figure, montée par le contrôleur `figure`.
# Aucune page de leçon v3 n'existe encore à ce lot : le partial rendu par le serveur est injecté dans une page réelle.
class Catalog::FigureSystemTest < ApplicationSystemTestCase
  THALES = {
    "points" => [ { "id" => "A", "x" => 0, "y" => 0 }, { "id" => "B", "x" => 8, "y" => 0 }, { "id" => "C", "x" => 0, "y" => 6 },
                  { "id" => "D", "x" => 4, "y" => 0, "draggable" => true }, { "id" => "E", "x" => 0, "y" => 3 } ],
    "segments" => [ [ "A", "B" ], [ "B", "C" ], [ "C", "A" ], [ "D", "E" ] ],
    "angles" => [ { "vertex" => "A", "from" => "B", "to" => "C", "mark" => "right" } ],
    "constraints" => [ { "point" => "D", "on" => "AB" }, { "point" => "E", "on" => "AC", "parallel_to" => "BC", "through" => "D" } ],
    "labels" => [ { "from" => "A", "to" => "D", "text" => "x" }, { "from" => "A", "to" => "B", "text" => "8" },
                  { "from" => "A", "to" => "E", "text" => "y" }, { "from" => "A", "to" => "C", "text" => "6" } ]
  }.freeze

  def figure(kind:, params:, controls: [])
    Entities::Catalog::Figure.new(key: "figure-test", kind:, params:, controls:,
                                  description: Factories::RevisionSheet::FIGURE_DESCRIPTION)
  end

  def mount(figure, controller: true)
    html = ApplicationController.render(partial: "catalog/figures/figure", locals: { figure: })
    html = html.sub('data-controller="figure"', "") unless controller
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

  def read(selector) = find(selector).text

  test "the Thales figure moves by keyboard and the ratios follow" do
    mount(figure(kind: "geometry", params: THALES))

    assert_selector "#host svg [data-point='D'][tabindex='0']"
    assert_selector "#host svg text", text: /AD\/AB = 0,50/
    find("#host svg [data-point='D']").send_keys(:arrow_right, :arrow_right)

    assert_selector "#host svg text", text: /AD\/AB = 0,75/
    assert_selector "#host svg text", text: /AD = 6,0/
    assert_selector "[aria-live='polite']", text: /AD\/AB/, visible: :all
  end

  test "the derived point E follows D and keeps the Thales ratios" do
    mount(figure(kind: "geometry", params: THALES))

    assert_selector "#host svg [data-dot='E']", visible: :all
    assert_no_selector "#host svg [data-point='E']", visible: :all
    assert_selector "#host svg text", text: /AE\/AC = 0,50/
    before = page.evaluate_script("Number(document.querySelector('#host [data-dot=E]').getAttribute('cy'))")
    find("#host svg [data-point='D']").send_keys(:arrow_right, :arrow_right)

    assert_selector "#host svg text", text: /AD\/AB = 0,75/
    assert_selector "#host svg text", text: /AE\/AC = 0,75/
    assert_selector "#host svg text", text: /AE = 4,5/
    after = page.evaluate_script("Number(document.querySelector('#host [data-dot=E]').getAttribute('cy'))")

    assert_operator after, :<, before
  end

  test "length labels do not overlap point names" do
    mount(figure(kind: "geometry", params: THALES))
    assert_selector "#host svg [data-length]", count: 4, visible: :all

    script = <<~JS
      const rect = (n) => n.getBoundingClientRect()
      const hit = (a, b) => a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom
      const names = [...document.querySelectorAll("#host [data-name]")].map(rect)
      return [...document.querySelectorAll("#host [data-length]")].some((n) => names.some((m) => hit(rect(n), m)))
    JS
    assert_equal false, page.evaluate_script("(() => { #{script} })()")
    find("#host svg [data-point='D']").send_keys(:arrow_right, :arrow_right, :arrow_right)

    assert_equal false, page.evaluate_script("(() => { #{script} })()")
  end

  test "a draggable point stays on its segment under the pointer" do
    mount(figure(kind: "geometry", params: THALES))
    handle = find("#host svg [data-point='D']")
    page.driver.browser.action.click_and_hold(handle.native).move_by(500, 0).release.perform

    assert_selector "#host svg text", text: /AD\/AB = 1,00/
  end

  test "a number line draws the interval and its slider changes the bound" do
    params = { "min" => -5, "max" => 5, "step" => 1, "points" => [ { "value" => 2, "label" => "x" } ],
               "intervals" => [ { "from" => -2, "to" => 3, "from_open" => true, "to_open" => false } ] }
    mount(figure(kind: "number_line", params:, controls: [ { "param" => "max", "min" => 3, "max" => 9, "step" => 1, "label" => "borne" } ]))

    assert_selector "#host svg [data-interval]", count: 1, visible: :all
    assert_selector "#host svg [data-tick]", count: 11, visible: :all
    find("input[type=range]").set(9)

    assert_selector "#host svg [data-tick]", count: 15, visible: :all
    assert_selector "#host svg [data-interval]", count: 1, visible: :all
  end

  test "a number line leaves no large gap under its axis" do
    mount(figure(kind: "number_line", params: { "min" => -5, "max" => 5, "step" => 1 }))
    assert_selector "#host svg [data-tick]", count: 11, visible: :all

    gap = page.evaluate_script(<<~JS)
      (() => {
        const svg = document.querySelector("#host svg").getBoundingClientRect()
        const lowest = Math.max(...[...document.querySelectorAll("#host svg text")].map((n) => n.getBoundingClientRect().bottom))
        return svg.bottom - lowest
      })()
    JS

    assert_operator gap, :<=, 14
  end

  test "without JavaScript or for an unknown kind, the description alone remains" do
    mount(figure(kind: "geometry", params: THALES), controller: false)

    assert_selector "figcaption", text: Factories::RevisionSheet::FIGURE_DESCRIPTION
    assert_no_selector "#host svg"

    mount(figure(kind: "hologram", params: {}))

    assert_selector "figcaption", text: Factories::RevisionSheet::FIGURE_DESCRIPTION
    assert_no_selector "#host svg"
  end

  test "a parameter out of bounds shows the description, not a broken drawing" do
    mount(figure(kind: "number_line", params: { "min" => 0, "max" => 5000, "step" => 0.0001 }))

    assert_selector "figcaption", text: Factories::RevisionSheet::FIGURE_DESCRIPTION
    assert_no_selector "#host svg [data-tick]", visible: :all
  end
end
