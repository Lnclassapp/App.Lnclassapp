require "application_system_test_case"

# contenu-en-blocs (#318), CA-5 à CA-9 et Lot G — ce que seul un navigateur juge : bulle du lexique, verdicts des exercices,
# score de « Je m'entraîne », figure de Thalès, mise en page à 390 px. Le rendu serveur (titres, encadrés, échappement,
# 404, data-*) est jugé par test/controllers/catalog/course_sheets_controller_test.rb et test/views/catalog/course_sheets/.
# Peu de tests, chacun enchaîne ses gestes sur une seule visite : le budget du chantier est de 15 s (ADR-0069 §9).
class Catalog::CourseSheetBrowserTest < ApplicationSystemTestCase
  BANK = [
    { "prompt" => "Calculer 2 + 2.", "answer" => 4, "solution" => "2 + 2 = 4." },
    { "prompt" => "Calculer 3 × 1,5.", "answer" => 4.5, "solution" => "3 × 1,5 = 4,5." }
  ].freeze
  FIGURE = "[data-controller~='course-sheet--thales-figure']".freeze

  def t(key, **) = I18n.t("catalog.course_sheets.#{key}", **)
  def figure(key, **) = t("kinds.thales_figure.#{key}", **)
  def field(id) = find("[data-field-id='#{id}'][data-input]")
  def feedback(id) = find("small[data-field-id='#{id}']", visible: :all)
  def metric(script) = page.evaluate_script(script)
  def role(name) = find("#{FIGURE} [data-role='#{name}']")
  def ratios = %w[1 2 3].map { find("#{FIGURE} [data-ratio='#{it}']").text }

  def open_reading_sheet(document = reading_course_sheet_document)
    @course = create_course(name: "Propriétés de Thalès")
    create_course_sheet(course: @course, document:)
    sign_in_as create_student_for(@course)
    visit course_path(@course.slug)
  end

  # Drags a point of the figure to a place of the 440 × 320 drawing, with real pointer events (Selenium actions).
  def drag(point, x:, y:)
    page.execute_script("document.querySelector(\"#{FIGURE} svg\").scrollIntoView({ block: 'center' })")
    handle = find("#{FIGURE} circle[data-hit='#{point}']")
    scale = page.evaluate_script("document.querySelector(\"#{FIGURE} svg\").getBoundingClientRect().width / 440")
    from = [ handle[:cx].to_f, handle[:cy].to_f ]
    page.driver.browser.action.move_to(handle.native).click_and_hold
        .move_by(((x - from[0]) * scale).round, ((y - from[1]) * scale).round).release.perform
  end

  test "the student reads: formulas, word bubble, glossary list, scroll, simple explanations" do
    open_reading_sheet
    assert_selector ".sheet-box .katex"

    first(".sheet-intro .sheet-word", text: "sécantes").click
    within(".sheet-bubble") do
      assert_text "Sécantes"
      assert_text "Deux droites sont sécantes quand elles se croisent en un point."
      assert_text "Comme deux routes qui se croisent à un carrefour."
    end
    find(".sheet-h1").click
    assert_no_selector ".sheet-bubble"

    first(".sheet-intro .sheet-word", text: "sécantes").click
    assert_selector ".sheet-bubble"
    page.execute_script("window.scrollBy(0, 300)")
    assert_no_selector ".sheet-bubble"

    click_on t("glossary.button")
    within(".sheet-bubble") do
      assert_selector ".sheet-bubble-term", count: 3
      click_on "Hypothèse"
      assert_text "Une information que l'énoncé te donne."
    end
    find(".sheet-h1").click
    click_on t("glossary.hint")
    within(".sheet-bubble") { assert_text t("glossary.help_title") }
    find(".sheet-h1").click

    assert_selector ".sheet-simple", text: "Le petit triangle AMN"
    click_on t("simple.label_on")
    assert_no_selector ".sheet-simple"
    assert_selector "button[aria-pressed='false']", text: t("simple.label_off")
    click_on t("simple.label_off")
    assert_selector ".sheet-simple", text: "Le petit triangle AMN"
  end

  test "exercises give their verdicts and the practice block counts the score once per prompt" do
    exercise = { "type" => "exercise", "title" => "Exercice 4", "prompt" => "Calculer AN et MN.",
                 "fields" => [
                   { "id" => "an", "input" => "numeric", "label" => "AN =", "answer" => 3.6 },
                   { "id" => "mn", "input" => "numeric", "label" => "MN =", "answer" => 4.2 },
                   { "id" => "par", "input" => "choice", "label" => "Les droites sont", "options" => [ "parallèles", "non parallèles" ], "answer" => 0 }
                 ],
                 "hint" => "Écris d'abord les trois rapports.", "correction" => "AN = 3 × 6 ÷ 5 = 3,6 cm." }
    frozen = { "type" => "exercise", "title" => "Exercice 5", "prompt" => "Complète la phrase.",
               "fields" => [ { "id" => "mot", "input" => "choice", "label" => "Connecteur", "options" => [ "car", "pourtant", "donc" ], "answer" => 0, "frozen" => true } ] }
    practice = { "type" => "practice", "kind" => "bank", "title" => "Je m'entraîne", "bank" => BANK }
    open_reading_sheet("pages" => [ { "sections" => [ { "title" => "Exercices", "blocks" => [ exercise, frozen, practice ] } ] } ], "glossary" => {})

    within(find(".sheet-card", text: "Exercice 4")) do
      assert_no_text "Écris d'abord les trois rapports."
      click_on t("exercise.hint")
      assert_text "Écris d'abord les trois rapports."
      click_on t("exercise.correction")
      assert_text "AN = 3 × 6 ÷ 5 = 3,6 cm."
      click_on t("exercise.correction")
      assert_no_text "AN = 3 × 6 ÷ 5 = 3,6 cm."

      click_on "non parallèles"
      click_on "parallèles", exact: true
      assert_selector "button[aria-pressed=true]", text: "parallèles", exact_text: true
      assert_equal "", feedback("par").text

      field("an").set("3,6")
      field("mn").set("4,5")
      click_on t("exercise.check")
      assert_equal t("exercise.correct"), feedback("an").text
      assert_equal t("exercise.correct"), feedback("par").text
      assert_equal t("exercise.wrong"), feedback("mn").text
      assert_text t("exercise.some_wrong")

      field("mn").set("4.2")
      field("an").set("18/5")
      click_on "non parallèles"
      click_on t("exercise.check")
      assert_equal t("exercise.correct"), feedback("an").text
      assert_equal t("exercise.correct"), feedback("mn").text
      assert_equal t("exercise.wrong"), feedback("par").text

      field("mn").set("4,2 cm")
      click_on t("exercise.check")
      assert_equal t("exercise.wrong"), feedback("mn").text
      field("mn").set("")
      click_on t("exercise.check")
      assert_equal t("exercise.incomplete"), feedback("mn").text
    end

    within(find(".sheet-card", text: "Exercice 5")) do
      click_on "pourtant"
      assert_equal t("exercise.wrong"), feedback("mot").text
      assert_selector "button[data-state=right]", text: "car"
      click_on "car"
      assert_selector "button[aria-pressed=true]", text: "pourtant"
      assert_no_selector "button[aria-pressed=true]", text: "car"
    end

    within(find(".sheet-practice")) do
      click_on t("practice.check")
      assert_text t("exercise.incomplete")
      assert_text t("practice.score", ok: 0, total: 0)

      first = find("[data-course-sheet--practice-target=prompt]").text
      find("input").set(BANK.find { it["prompt"] == first }.fetch("answer").to_s.tr(".", ","))
      find("input").send_keys(:enter)
      assert_text t("practice.score", ok: 1, total: 1)
      click_on t("practice.check")
      assert_text t("practice.score", ok: 1, total: 1)

      click_on t("practice.solution")
      assert_text BANK.find { it["prompt"] == first }.fetch("solution")
      click_on t("practice.next")
      assert_no_text first
      assert_equal "", find("input").value

      find("input").set("0")
      click_on t("practice.check")
      assert_text t("practice.score", ok: 1, total: 2)
    end
  end

  test "the Thalès figure follows the pointer, locks N, frees it, resets, and the exercise and generator count" do
    @course = create_course(name: "Propriétés de Thalès dans un triangle", level: create_level(name: "3ème"))
    create_course_sheet(course: @course, document: JSON.parse(Rails.root.join("db/seeds/data/course_sheets/thales.json").read))
    sign_in_as create_student_for(@course)
    visit course_path(@course.slug)
    # La fiche est coupée après 150 mots dans la page de la leçon (UDR-0139 §3.2) : la figure est dans la suite.
    click_on I18n.t("catalog.courses.show.revision_more")
    assert_selector FIGURE

    drag("M", x: 30, y: 180)
    assert_selector "#{FIGURE} [data-role='config']", text: figure("config_butterfly")
    assert_equal 1, ratios.uniq.size, ratios.inspect
    assert_equal figure("status_locked"), role("status").text

    drag("A", x: 110, y: 200)
    assert_not_in_delta 70, find("#{FIGURE} circle[data-hit='A']")[:cx].to_f, 1

    click_on t("figure.reset")
    assert_equal figure("config_triangle"), role("config").text
    assert_equal %w[0,45 0,45 0,45], ratios
    { "A" => [ 70, 165 ], "B" => [ 360, 55 ], "C" => [ 345, 285 ] }.each do |name, (x, y)|
      hit = find("#{FIGURE} circle[data-hit='#{name}']")
      assert_in_delta x, hit[:cx].to_f, 1, "#{name} cx"
      assert_in_delta y, hit[:cy].to_f, 1, "#{name} cy"
    end

    click_on figure("lock_free")
    drag("N", x: 250, y: 200)
    assert_equal figure("status_contraposed"), role("status").text
    assert_not_equal ratios[0], ratios[1], ratios.inspect
    click_on figure("lock_impose")
    assert_equal figure("status_locked"), role("status").text
    assert_equal 1, ratios.uniq.size
    click_on t("figure.reset")
    assert_button figure("lock_free")

    within(find(".sheet-card", text: "Exercice 4")) do
      find("input[data-field-id='e4an']").set("3,62")
      find("input[data-field-id='e4mn']").set("4.2")
      click_on t("exercise.check")
      assert_equal t("exercise.wrong"), find("small[data-field-id='e4an']", visible: :all).text
      find("input[data-field-id='e4an']").set("3,6")
      click_on t("exercise.check")
      assert_text t("exercise.all_correct")
    end
    within(find("section[data-controller~='course-sheet--practice']")) do
      click_on t("practice.solution")
      answer = find("[data-course-sheet--practice-target='solution']").text[/=\s*([\d,]+) cm\.\z/, 1]
      assert answer, "la solution ne se termine pas par « = … cm. »"
      find("input[data-course-sheet--practice-target='input']").set(answer)
      click_on t("practice.check")
      click_on t("practice.check")
      assert_text t("practice.score", ok: 1, total: 1)
    end
  end

  test "at 390 px the sheet is fluid, the targets are 44 px and the lexicon is a drawer" do
    document = reading_course_sheet_document
    document["pages"].first["sections"].first["blocks"] << { "type" => "exercise", "title" => "Exercice 4", "prompt" => "Calculer AN.",
      "fields" => [ { "id" => "an", "input" => "numeric", "label" => "AN =", "answer" => 3.6 } ] }
    @course = create_course(name: "Propriétés de Thalès")
    create_course_sheet(course: @course, document:)
    sign_in_as create_student_for(@course)

    with_mobile_viewport do
      visit course_path(@course.slug)
      assert_selector ".sheet-page", minimum: 3

      assert_operator metric("document.documentElement.scrollWidth"), :<=, 390
      assert_operator metric("document.querySelector('.sheet-screen').scrollWidth"), :<=, metric("document.querySelector('.sheet-screen').clientWidth")
      assert_operator metric("document.querySelector('.sheet-page').getBoundingClientRect().width"), :<=, 390
      assert_equal "16px", metric("getComputedStyle(document.querySelector('.sheet-page-body')).paddingRight")
      assert_equal "block", metric("getComputedStyle(document.querySelector('.sheet-table tbody tr')).display")
      assert_equal "none", metric("getComputedStyle(document.querySelector('.sheet-table thead')).display")
      assert_not_equal "none", metric("getComputedStyle(document.querySelector('.sheet-table td'), '::before').content")

      heights = metric('[ ...document.querySelectorAll(".sheet-toggle, .sheet-btn, .sheet-input") ].map((e) => Math.round(e.getBoundingClientRect().height))')
      assert_not_empty heights
      assert_operator heights.min, :>=, 44

      click_on t("glossary.button")
      assert_selector ".sheet-bubble", visible: :visible
      box = metric("(() => { const r = document.querySelector('.sheet-bubble').getBoundingClientRect(); return [ r.left, r.right, r.bottom, r.height, innerHeight, document.documentElement.clientWidth ] })()")
      assert_in_delta 0, box[0], 1
      assert_in_delta box[5], box[1], 1
      assert_in_delta box[4], box[2], 1
      assert_operator box[3], :<=, box[4] * 0.6 + 1
      assert_equal "20px", metric("getComputedStyle(document.querySelector('.sheet-bubble')).borderTopLeftRadius")
      assert_operator metric("document.querySelector('.sheet-bubble-close').getBoundingClientRect().height"), :>=, 44
      assert_operator metric("document.querySelector('.sheet-bubble-close').getBoundingClientRect().width"), :>=, 44

      find(".sheet-bubble-close").click
      assert_no_selector ".sheet-bubble"
      click_on t("glossary.button")
      page.send_keys(:escape)
      assert_no_selector ".sheet-bubble"
      click_on t("glossary.button")
      find(".sheet-h1").click
      assert_no_selector ".sheet-bubble"
    end
  end
end
