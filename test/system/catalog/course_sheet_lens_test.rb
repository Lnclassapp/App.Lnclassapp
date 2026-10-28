require "application_system_test_case"

# contenu-en-blocs (#318), Lot E, CA-10 — la fiche Lentilles livrée avec les seeds, jugée dans un navigateur : le simulateur
# (rayons, image virtuelle en pointillés, application « loupe », grille, foyers, clavier), l'exercice de construction (point image
# placé juste, score compté une fois par énoncé) et la mise en page à 390 px (pas de défilement horizontal, cibles de 44 px).
# Le rendu serveur (défauts, bornes, figure inconnue) est jugé par test/integration/catalog/course_sheet_lens_document_test.rb.
# Peu de visites et peu de glissements : la suite système ne grandit que de 15 s par chantier (ADR-0069 § 9).
class Catalog::CourseSheetLensTest < ApplicationSystemTestCase
  SIMULATOR = "[data-controller~='course-sheet--lens-simulator']".freeze
  CONSTRUCTION = "[data-controller~='course-sheet--lens-construction']".freeze
  SHEET = Rails.root.join("db/seeds/data/course_sheets/lentilles.json")

  def t(key, **) = I18n.t("catalog.course_sheets.#{key}", **)
  def sim(key, **) = t("kinds.lens_simulator.#{key}", **)
  def role(scope, name) = find("#{scope} [data-role='#{name}']", visible: :all)
  def press(scope, label) = within(scope) { click_on label }
  # Les contrôleurs Stimulus chargent leur logique à la demande : `data-ready` dit que la figure répond aux gestes.
  def ready(scope) = assert_selector("#{scope}[data-ready='true']")
  def metric(script) = page.evaluate_script(script)
  # Les textes de la figure d'un coup (un aller-retour avec le navigateur) : { "oa" => "8 cm", … } et "virtual" : le nombre de rayons en pointillés.
  def read(scope)
    page.evaluate_script(<<~JS)
      Object.assign(Object.fromEntries([ ...document.querySelectorAll("#{scope} [data-role]") ].map((e) => [ e.dataset.role, e.textContent.trim() ])),
        { virtual: document.querySelectorAll("#{scope} .sheet-lens-ray[data-virtual='true']").length })
    JS
  end
  def scroll_to(scope) = page.execute_script("document.querySelector(\"#{scope} svg\").scrollIntoView({ block: 'center' })")

  def open_sheet(visit: true)
    @course = create_course(name: "Les lentilles", level: create_level(name: "3ème"), material: create_material(name: "Physique-Chimie"))
    create_course_sheet(course: @course, theme: "teal", document: JSON.parse(SHEET.read))
    sign_in_as create_student_for(@course)
    visit course_sheet_path(@course.slug) if visit
  end

  # Moves a hit zone to a place of the drawing (viewBox width x height), with real pointer events.
  def drag(scope, hit, x:, y:, width: 560)
    ready(scope)
    scroll_to(scope)
    handle = find("#{scope} circle[data-hit='#{hit}']")
    scale = page.evaluate_script("document.querySelector(\"#{scope} svg\").getBoundingClientRect().width / #{width}")
    page.driver.browser.action.move_to(handle.native).click_and_hold
        .move_by(((x - handle[:cx].to_f) * scale).round, ((y - handle[:cy].to_f) * scale).round).release.perform
  end

  test "the sheet imported from the seeds reads, and its simulator draws the real image, then the virtual one, and follows the keyboard" do
    open_sheet

    assert_selector "h1", text: "Les lentilles"
    assert_selector ".sheet-screen[data-sheet-theme='teal']"
    assert_selector ".sheet-lens-diagram", count: 7
    %w[families vocabulary example eye ametropia profiles focal].each { assert_selector ".sheet-lens-diagram[data-diagram='#{it}'] svg" }
    assert_selector ".sheet-card[data-controller~='course-sheet--exercise']", count: 7
    assert_no_text t("block.unavailable")
    first(".sheet-lens-diagram[data-diagram='families'] .sheet-word", text: "convergente").click
    within(".sheet-bubble") { assert_text "Qui rassemble." }

    ready(SIMULATOR)
    now = read(SIMULATOR)
    assert_equal [ sim("js.application_photo"), sim("js.nature_real", size: sim("js.size_smaller")), 0 ], now.values_at("application", "nature", "virtual")
    assert_selector "#{SIMULATOR} [data-role='image'] [data-role='image-line'][data-virtual='false']", visible: :all

    # B de 8 cm à 1,5 cm de la lentille : en deçà du foyer (3 cm), l'image devient virtuelle (CA-10)
    drag(SIMULATOR, "B", x: 270, y: 130)
    now = read(SIMULATOR)
    assert_equal [ sim("js.application_magnifier"), sim("js.nature_virtual"), "1,5 cm", sim("js.status_virtual") ], now.values_at("application", "nature", "oa", "status")
    assert_operator now["virtual"], :>=, 3
    assert_selector "#{SIMULATOR} [data-role='image-line'][data-virtual='true']", visible: :all
    assert_selector "#{SIMULATOR} button[data-preset='magnifier'][aria-current='true']"

    press(SIMULATOR, sim("preset_projector"))
    now = read(SIMULATOR)
    assert_equal [ sim("js.application_projector"), sim("js.nature_real", size: sim("js.size_bigger")), 0, sim("js.status_real"), "4 cm" ],
                 now.values_at("application", "nature", "virtual", "status", "oa")

    press(SIMULATOR, sim("preset_magnifier"))
    assert_equal [ "2 cm", "4 cm", sim("js.oap_virtual", value: "4") ], read(SIMULATOR).values_at("oa", "f", "oap")

    press(SIMULATOR, sim("js.grid_hide"))
    assert_selector "#{SIMULATOR} [data-role='grid'][data-visible='false']", visible: :all
    press(SIMULATOR, sim("js.grid_show"))
    assert_selector "#{SIMULATOR} [data-role='grid'][data-visible='true']", visible: :all

    # F′ glisse sur l'axe : f passe de 4 à 5 cm
    drag(SIMULATOR, "Fp", x: 400, y: 170)
    assert_equal "5 cm", read(SIMULATOR)["f"]

    # Les flèches déplacent le foyer F, Majuscule pour de petits pas ; B suit aussi le clavier
    press(SIMULATOR, sim("preset_photo"))
    find("#{SIMULATOR} circle[data-hit='F']").send_keys(:left)
    assert_equal "3,5 cm", read(SIMULATOR)["f"]
    find("#{SIMULATOR} circle[data-hit='F']").send_keys([ :shift, :right ])
    assert_equal "3,4 cm", read(SIMULATOR)["f"]
    find("#{SIMULATOR} circle[data-hit='B']").send_keys(:left)
    assert_equal "12,5 cm", read(SIMULATOR)["oa"]

    # L'objet au foyer : les rayons ressortent parallèles, pas d'image nette
    press(SIMULATOR, sim("preset_projector"))
    find("#{SIMULATOR} circle[data-hit='Fp']").send_keys(:right, :right)
    assert_equal [ sim("js.nature_none"), sim("js.oap_infinite"), sim("js.application_none") ], read(SIMULATOR).values_at("nature", "oap", "application")
  end

  test "the construction counts the score once per prompt, accepts the image point placed right, and shows the solution" do
    open_sheet
    ready(CONSTRUCTION)
    scroll_to(CONSTRUCTION)
    assert_text t("practice.score", ok: 0, total: 0)

    answer = lambda do
      f, d, h = %w[f d h].map { find(CONSTRUCTION)["data-#{it}"].to_f }
      image = d * f / (d - f)
      [ 260 + image * 20, 130 + (image / d) * h * 20 ]
    end

    x, y = answer.call
    drag(CONSTRUCTION, "marker", x:, y:)
    press(CONSTRUCTION, t("practice.check"))
    assert_match(/\A#{Regexp.escape(t('kinds.lens_construction.js.right_start'))}/, role(CONSTRUCTION, "message").text)
    assert_text t("practice.score", ok: 1, total: 1)
    press(CONSTRUCTION, t("practice.check"))
    assert_text t("practice.score", ok: 1, total: 1)

    # Le marqueur se pousse aussi aux flèches : le message s'efface, la réponse n'est plus juste
    find("#{CONSTRUCTION} circle[data-hit='marker']").send_keys(:left)
    assert_equal "", role(CONSTRUCTION, "message").text

    press(CONSTRUCTION, t("practice.solution"))
    assert_selector "#{CONSTRUCTION} [data-role='solution'][data-visible='true'] .sheet-lens-ray", minimum: 3, visible: :all
    press(CONSTRUCTION, t("kinds.lens_construction.js.solution_hide"))
    assert_selector "#{CONSTRUCTION} [data-role='solution'][data-visible='false']", visible: :all

    prompt = role(CONSTRUCTION, "prompt").text
    press(CONSTRUCTION, t("practice.next"))
    assert_no_text prompt
    assert_equal "", role(CONSTRUCTION, "message").text
    press(CONSTRUCTION, t("practice.check"))
    assert_equal t("kinds.lens_construction.js.wrong"), role(CONSTRUCTION, "message").text
    assert_text t("practice.score", ok: 1, total: 2)
  end

  test "at 390 px the lens sheet does not scroll sideways and every handle is a 44 px target" do
    open_sheet(visit: false)

    with_mobile_viewport do
      visit course_sheet_path(@course.slug)
      ready(SIMULATOR)
      ready(CONSTRUCTION)

      assert_operator metric("document.documentElement.scrollWidth"), :<=, 390
      assert_operator metric("document.querySelector('.sheet-screen').scrollWidth"), :<=, metric("document.querySelector('.sheet-screen').clientWidth")
      overflow = metric(<<~JS)
        [ ...document.querySelectorAll(".sheet-lens-diagram, .sheet-lens svg, .sheet-practice svg") ]
          .filter((e) => e.getBoundingClientRect().right > 390.5).map((e) => e.className.baseVal ?? e.className)
      JS
      assert_empty overflow

      [ SIMULATOR, CONSTRUCTION ].each do |scope|
        scroll_to(scope)
        sizes = metric("[ ...document.querySelectorAll(\"#{scope} circle[data-hit]\") ].map((e) => { const r = e.getBoundingClientRect(); return Math.round(Math.min(r.width, r.height)) })")
        assert_not_empty sizes
        assert_operator sizes.min, :>=, 44, "#{scope} : #{sizes}"
      end

      buttons = metric("[ ...document.querySelectorAll(\".sheet-lens-panel .sheet-btn, .sheet-practice .sheet-btn\") ].map((e) => Math.round(e.getBoundingClientRect().height))")
      assert_operator buttons.min, :>=, 44

      # La figure se manipule au doigt : B se déplace avec les mêmes gestes qu'à la souris
      drag(SIMULATOR, "B", x: 270, y: 130)
      assert_equal sim("js.application_magnifier"), read(SIMULATOR)["application"]
      assert_operator metric("document.documentElement.scrollWidth"), :<=, 390
    end
  end

  test "in the lesson page the sheet unfolds on the spot and the simulator works there too" do
    open_sheet(visit: false)

    visit course_path(@course.slug)
    click_on I18n.t("catalog.courses.show.revision_more")
    ready(SIMULATOR)
    assert_equal sim("js.application_photo"), read(SIMULATOR)["application"]
  end
end
