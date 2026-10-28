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
  # Chaque texte de la figure, attendu en entier (Capybara patiente le temps du rendu) : shows(SIMULATOR, oa: "8 cm", f: "3 cm")
  def shows(scope, **texts)
    texts.each { |name, text| assert_selector "#{scope} [data-role='#{name.to_s.tr('_', '-')}']", exact_text: text, visible: :all }
  end

  def before_cache = page.execute_script("document.dispatchEvent(new CustomEvent('turbo:before-cache'))")

  def assert_rays(scope, virtual:) = assert_selector("#{scope} .sheet-lens-ray[data-virtual='true']", count: virtual, visible: :all)

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
    shows(SIMULATOR, application: sim("js.application_photo"), nature: sim("js.nature_real", size: sim("js.size_smaller")), status: sim("js.status_real"))
    assert_rays SIMULATOR, virtual: 0
    assert_selector "#{SIMULATOR} [data-role='image'] [data-role='image-line'][data-virtual='false']", visible: :all
    assert_selector "#{SIMULATOR} button[data-preset='photo'][aria-current='true']"

    # B de 8 cm à 1,5 cm de la lentille : en deçà du foyer (3 cm), l'image devient virtuelle (CA-10)
    drag(SIMULATOR, "B", x: 270, y: 130)
    shows(SIMULATOR, application: sim("js.application_magnifier"), nature: sim("js.nature_virtual"), oa: "1,5 cm", status: sim("js.status_virtual"))
    assert_rays SIMULATOR, virtual: 4
    assert_selector "#{SIMULATOR} [data-role='image-line'][data-virtual='true']", visible: :all
    assert_selector "#{SIMULATOR} button[data-preset='magnifier'][aria-current='true']"
    assert_no_selector "#{SIMULATOR} button[data-preset='photo'][aria-current]"

    press(SIMULATOR, sim("preset_projector"))
    shows(SIMULATOR, application: sim("js.application_projector"), nature: sim("js.nature_real", size: sim("js.size_bigger")), status: sim("js.status_real"), oa: "4 cm")
    assert_rays SIMULATOR, virtual: 0

    press(SIMULATOR, sim("preset_magnifier"))
    shows(SIMULATOR, oa: "2 cm", f: "4 cm", oap: sim("js.oap_virtual", value: "4"))

    press(SIMULATOR, sim("js.grid_hide"))
    assert_selector "#{SIMULATOR} [data-role='grid'][data-visible='false']", visible: :all
    press(SIMULATOR, sim("js.grid_show"))
    assert_selector "#{SIMULATOR} [data-role='grid'][data-visible='true']", visible: :all

    # F′ glisse sur l'axe : f passe de 4 à 5 cm
    drag(SIMULATOR, "Fp", x: 400, y: 170)
    shows(SIMULATOR, f: "5 cm")

    # Les flèches déplacent le foyer F, Majuscule pour de petits pas ; B suit aussi le clavier
    press(SIMULATOR, sim("preset_photo"))
    find("#{SIMULATOR} circle[data-hit='F']").send_keys(:left)
    shows(SIMULATOR, f: "3,5 cm")
    find("#{SIMULATOR} circle[data-hit='F']").send_keys([ :shift, :right ])
    shows(SIMULATOR, f: "3,4 cm")
    find("#{SIMULATOR} circle[data-hit='B']").send_keys(:left)
    shows(SIMULATOR, oa: "12,5 cm")

    # L'objet au foyer : les rayons ressortent parallèles, pas d'image nette
    press(SIMULATOR, sim("preset_projector"))
    find("#{SIMULATOR} circle[data-hit='Fp']").send_keys(:right, :right)
    shows(SIMULATOR, nature: sim("js.nature_none"), oap: sim("js.oap_infinite"), application: sim("js.application_none"), status: sim("js.status_none"))

    # Juste au-delà du foyer (d = 3,1 cm, f = 3 cm) l'image existe, à 93 cm : trop loin pour le dessin, la figure le dit
    press(SIMULATOR, sim("preset_projector"))
    find("#{SIMULATOR} circle[data-hit='B']").send_keys(*Array.new(9) { [ :shift, :right ] })
    shows(SIMULATOR, oa: "3,1 cm", f: "3 cm", oap: sim("js.oap_real", value: "93"), status: sim("js.status_far"))
    assert_selector "#{SIMULATOR} [data-role='image'][data-visible='false']", visible: :all

    # Avant le cache de Turbo la figure revient à l'état du serveur : le retour arrière ne la montre pas à moitié jouée
    before_cache
    assert_no_selector "#{SIMULATOR}[data-ready]"
    shows(SIMULATOR, oa: "8 cm", f: "3 cm", status: sim("js.status_real"))
  end

  test "the construction counts the score once per prompt, accepts the image point placed right, and shows the solution" do
    open_sheet
    ready(CONSTRUCTION)
    scroll_to(CONSTRUCTION)
    shows(CONSTRUCTION, score: t("practice.score", ok: 0, total: 0), message: "")

    answer = lambda do
      f, d, h = %w[f d h].map { find(CONSTRUCTION)["data-#{it}"].to_f }
      image = d * f / (d - f)
      [ 260 + image * 20, 130 + (image / d) * h * 20 ]
    end

    x, y = answer.call
    drag(CONSTRUCTION, "marker", x:, y:)
    press(CONSTRUCTION, t("practice.check"))
    assert_selector "#{CONSTRUCTION} [data-role='message'][data-state='correct']", text: /\A#{Regexp.escape(t('kinds.lens_construction.js.right_start'))}/
    shows(CONSTRUCTION, score: t("practice.score", ok: 1, total: 1))
    press(CONSTRUCTION, t("practice.check"))
    shows(CONSTRUCTION, score: t("practice.score", ok: 1, total: 1))
    assert_no_text t("practice.score", ok: 2, total: 2)

    # Le marqueur se pousse aussi aux flèches : le message s'efface, la réponse n'est plus juste
    find("#{CONSTRUCTION} circle[data-hit='marker']").send_keys(:left)
    shows(CONSTRUCTION, message: "")

    press(CONSTRUCTION, t("practice.solution"))
    assert_selector "#{CONSTRUCTION} [data-role='solution'][data-visible='true'] .sheet-lens-ray", minimum: 3, visible: :all
    press(CONSTRUCTION, t("kinds.lens_construction.js.solution_hide"))
    assert_selector "#{CONSTRUCTION} [data-role='solution'][data-visible='false']", visible: :all

    # L'énoncé suivant est un autre énoncé, écrit en entier d'après ses valeurs (f, OA, AB)
    before = %w[f d h].map { find(CONSTRUCTION)["data-#{it}"] }
    press(CONSTRUCTION, t("practice.next"))
    assert_no_selector "#{CONSTRUCTION}[data-f='#{before[0]}'][data-d='#{before[1]}'][data-h='#{before[2]}']"
    f, d, h = %w[f d h].map { find(CONSTRUCTION)["data-#{it}"].to_f }
    number = ->(value) { value.to_s.delete_suffix(".0").tr(".", ",") }
    shows(CONSTRUCTION, prompt: t("kinds.lens_construction.js.prompt", f: number.(f), h: number.(h), d: number.(d)), message: "")
    press(CONSTRUCTION, t("practice.check"))
    shows(CONSTRUCTION, message: t("kinds.lens_construction.js.wrong"), score: t("practice.score", ok: 1, total: 2))

    before_cache
    assert_no_selector "#{CONSTRUCTION}[data-ready]"
    shows(CONSTRUCTION, score: t("practice.score", ok: 0, total: 0), message: "")
    assert_selector "#{CONSTRUCTION}[data-f='2'][data-d='3'][data-h='1.5']"
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

      # Le doigt déplace les poignées sans faire défiler la page : touch-action vaut none sur les deux dessins
      assert_equal [ "none", "none" ], metric("[ ...document.querySelectorAll(\"#{SIMULATOR} svg, #{CONSTRUCTION} svg\") ].map((e) => getComputedStyle(e).touchAction)")

      buttons = metric("[ ...document.querySelectorAll(\".sheet-lens-panel .sheet-btn, .sheet-practice .sheet-btn\") ].map((e) => Math.round(e.getBoundingClientRect().height))")
      assert_operator buttons.min, :>=, 44

      # La figure se manipule au doigt : B se déplace avec les mêmes gestes qu'à la souris
      drag(SIMULATOR, "B", x: 270, y: 130)
      shows(SIMULATOR, application: sim("js.application_magnifier"))
      assert_operator metric("document.documentElement.scrollWidth"), :<=, 390
    end
  end

  test "in the lesson page the sheet unfolds on the spot and the simulator works there too" do
    open_sheet(visit: false)

    visit course_path(@course.slug)
    click_on I18n.t("catalog.courses.show.revision_more")
    ready(SIMULATOR)
    shows(SIMULATOR, application: sim("js.application_photo"))
  end
end
