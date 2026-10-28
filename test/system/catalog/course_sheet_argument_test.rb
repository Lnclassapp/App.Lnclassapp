require "application_system_test_case"

# contenu-en-blocs (#318), Lot F, CA-11 — ce que seul un navigateur juge sur la fiche « Le texte argumentatif » : surligneurs et
# explication d'un passage, tableau des connecteurs, choix figé, rédaction et ses vérifications (sans envoi au serveur), rendu à 390 px.
# La fiche est celle des seeds, lue dans la page de la leçon (UDR-0139). Le rendu serveur est jugé par
# test/integration/catalog/course_sheet_argument_seeds_test.rb et test/views/catalog/course_sheets/argument_test.rb.
class Catalog::CourseSheetArgumentTest < ApplicationSystemTestCase
  PATH = Rails.root.join("db/seeds/data/course_sheets/texte-argumentatif.json")
  TRANSPARENT = "rgba(0, 0, 0, 0)".freeze
  HIGHLIGHTER = "[data-controller~='course-sheet--argument-highlighter']".freeze
  WRITING = "[data-controller~='course-sheet--writing']".freeze
  TEXT = <<~TEXT.strip
    Aujourd'hui, de nombreux adolescents utilisent les réseaux sociaux. Selon moi, ils peuvent devenir un danger.

    D'abord, ils isolent. En effet, on passe des heures devant un écran. Par exemple, un élève qui veille tard dort mal.

    Enfin, qui voudrait perdre ses amis ? En conclusion, il faut apprendre à les utiliser avec mesure.
  TEXT

  def t(key, **) = I18n.t("catalog.course_sheets.#{key}", **)
  def hl(key, **) = t("kinds.argument_highlighter.#{key}", **)
  def writing(key, **) = t("blocks.writing.#{key}", **)
  def metric(script) = page.evaluate_script(script)
  def requests = metric("performance.getEntriesByType('resource').filter((e) => ['fetch', 'xmlhttprequest'].includes(e.initiatorType)).length")
  def background(selector) = metric("getComputedStyle(document.querySelector(\"#{selector}\")).backgroundColor")

  # Une vérification de la rédaction attend son état : la liste se met à jour à la frappe, pas avant le retour du navigateur.
  def assert_check(name, state) = assert_selector "#{WRITING} li[data-check='#{name}'][data-state='#{state}']"

  def open_sheet
    document = JSON.parse(PATH.read)
    yield document if block_given?
    @course = create_course(name: "Le texte argumentatif", level: create_level(name: "3ème"))
    create_course_sheet(course: @course, theme: document["theme"], document: document.slice("pages", "glossary"))
    sign_in_as create_student_for(@course)
    visit course_path(@course.slug)
    find("button", text: I18n.t("catalog.courses.show.revision_more")).click
    await_figures
  end

  # Les deux logiques sont chargées à la demande : on attend qu'elles soient branchées avant le premier geste.
  def await_figures
    assert_selector "#{HIGHLIGHTER}[data-ready='true']"
    assert_selector "#{WRITING}[data-ready='true']"
  end

  test "the student highlights the thesis, reads why, lights everything, picks a frozen connector and writes with the checklist" do
    open_sheet
    assert_selector ".sheet-screen[data-sheet-theme='burgundy']"
    assert_selector ".sheet-page", count: 3

    within(HIGHLIGHTER) do
      assert_text hl("idle")
      assert_no_selector ".sheet-hl-seg[data-on]"
      # Un passage non allumé ne répond pas et n'est pas coloré.
      assert_equal TRANSPARENT, background("#{HIGHLIGHTER} .sheet-hl-seg[data-kind='thesis']")
      first(".sheet-hl-seg[data-kind='thesis']").click
      assert_text hl("idle")

      click_on hl("categories.thesis.name")
      assert_selector ".sheet-hl-btn[data-kind='thesis'][aria-pressed='true']"
      assert_selector ".sheet-hl-seg[data-kind='thesis'][data-on]", minimum: 2
      assert_no_selector ".sheet-hl-seg[data-kind='argument'][data-on]"
      assert_not_equal TRANSPARENT, background("#{HIGHLIGHTER} .sheet-hl-seg[data-kind='thesis']")
      assert_equal TRANSPARENT, background("#{HIGHLIGHTER} .sheet-hl-seg[data-kind='argument']")

      first(".sheet-hl-seg[data-kind='thesis']").click
      assert_selector ".sheet-hl-info b", text: "#{hl('categories.thesis.name')} :"
      assert_text hl("categories.thesis.why")

      click_on hl("categories.thesis.name")
      assert_no_selector ".sheet-hl-seg[data-on]"
      assert_text hl("idle")
      assert_equal TRANSPARENT, background("#{HIGHLIGHTER} .sheet-hl-seg[data-kind='thesis']")

      # Au clavier : Entrée sur un passage allumé affiche l'explication.
      click_on hl("categories.argument.name")
      assert_selector ".sheet-hl-seg[data-kind='argument'][data-on][tabindex='0']", minimum: 1
      first(".sheet-hl-seg[data-kind='argument'][data-on]").send_keys(:enter)
      assert_selector ".sheet-hl-info[data-kind='argument']"
      assert_text hl("categories.argument.why")
      click_on hl("categories.argument.name")

      click_on hl("all_on")
      assert_selector ".sheet-hl-btn[aria-pressed='true']", count: 5
      first(".sheet-hl-seg[data-kind='connector']").click
      assert_text hl("categories.connector.why")
      click_on hl("all_off")
      assert_no_selector ".sheet-hl-seg[data-on]"
    end

    assert_selector ".sheet-table tbody tr", count: 7

    exercise = find(".sheet-card", text: "Le bon connecteur")
    within(exercise) do
      assert_selector "[data-frozen='true']", count: 4
      first("[data-field-id='e5a'] button", text: "car").click
      assert_equal t("exercise.wrong"), find("small[data-field-id='e5a']").text
      first("[data-field-id='e5a'] button", text: "cependant").click
      assert_equal t("exercise.wrong"), find("small[data-field-id='e5a']").text
      assert_selector "[data-field-id='e5a'] button[data-state='right']", text: "cependant"
    end

    within(WRITING) do
      assert_selector "li[data-check]", minimum: 5
      assert_check "opinion", "todo"
      assert_selector "[data-role='stats']", exact_text: "0 mots · 0 paragraphe(s)"

      before = requests
      find(".sheet-writing-input").set(TEXT)
      %w[opinion paragraphs connectors example question conclusion].each { assert_check it, "done" }
      assert_selector "[data-role='found'] .sheet-writing-pill", exact_text: "d'abord"
      assert_selector "[data-role='found'] .sheet-writing-pill", exact_text: "en conclusion"
      assert_selector "[data-role='count']", exact_text: "5"
      assert_selector "[data-role='stats']", exact_text: "#{TEXT.split.size} mots · 3 paragraphe(s)"

      find(".sheet-writing-input").set("Un seul paragraphe, donc rien d'autre.")
      assert_check "paragraphs", "todo"
      assert_check "conclusion", "todo"
      assert_equal before, requests, "la rédaction ne part pas au serveur"
    end
    assert_no_selector "#{WRITING} form"
    assert_no_selector "#{WRITING} textarea[name]"
  end

  test "the writing connector list is read like the student text: curly apostrophes, longest first, whole words, any case" do
    open_sheet do |document|
      block = document["pages"].flat_map { it["sections"] }.flat_map { it["blocks"] }.find { it["type"] == "writing" }
      block["connectors"] = [ "Cependant", "tout d'abord", "d'abord", "car", "mais", "parce qu'" ]
    end

    within(WRITING) do
      find(".sheet-writing-input").set("D’abord, une carte dans la maison.")
      assert_selector "[data-role='found'] .sheet-writing-pill", exact_text: "d'abord"
      assert_selector "[data-role='count']", exact_text: "1"

      find(".sheet-writing-input").set("Tout d'abord, oui. Cependant, non. Parce qu’il pleut.")
      assert_selector "[data-role='count']", exact_text: "3"
      assert_selector "[data-role='found'] .sheet-writing-pill", exact_text: "tout d'abord"
      assert_selector "[data-role='found'] .sheet-writing-pill", exact_text: "cependant"
      assert_selector "[data-role='found'] .sheet-writing-pill", exact_text: "parce qu'"
      assert_no_selector "[data-role='found'] .sheet-writing-pill", exact_text: "d'abord"
    end
  end

  test "after Turbo back navigation the highlighter shows its idle state and still answers" do
    open_sheet

    within(HIGHLIGHTER) do
      click_on hl("categories.thesis.name")
      first(".sheet-hl-seg[data-kind='thesis'][data-on]").click
      assert_selector ".sheet-hl-info[data-kind='thesis']"
    end

    within(WRITING) do
      find(".sheet-writing-input").set("Selon moi, c'est vrai.")
      assert_check "opinion", "done"
    end

    # Une visite Turbo (pas un chargement complet) : c'est elle qui garde la page en cache, puis la rend au retour arrière.
    # L'écouteur ajouté ici passe après ceux des contrôleurs : il lit la page telle que Turbo va la copier dans son cache.
    page.execute_script(<<~JS, root_path)
      window.sheetMarker = true
      document.addEventListener("turbo:before-cache", () => {
        const light = document.querySelector("#{HIGHLIGHTER}")
        const write = document.querySelector("#{WRITING}")
        window.sheetCached = {
          ready: [light.dataset.ready ?? null, write.dataset.ready ?? null],
          lit: light.querySelectorAll("[data-on], [aria-pressed='true']").length,
          kind: light.querySelector(".sheet-hl-info").dataset.kind ?? null,
          opinion: write.querySelector("[data-check='opinion']").dataset.state,
          typed: write.querySelector("textarea").value
        }
      }, { once: true })
      Turbo.visit(arguments[0])
    JS
    assert_no_current_path course_path(@course.slug)
    page.go_back
    assert_current_path course_path(@course.slug)
    assert metric("window.sheetMarker === true"), "le retour arrière est une restauration Turbo, pas un rechargement complet"
    assert_equal({ "ready" => [ nil, nil ], "lit" => 0, "kind" => nil, "opinion" => "todo", "typed" => "" }, metric("window.sheetCached"))

    assert_selector "#{HIGHLIGHTER}[data-ready='true']", visible: :all
    within(HIGHLIGHTER, visible: :all) do
      assert_selector ".sheet-hl-info [data-role='text']", text: hl("idle"), visible: :all
      assert_no_selector ".sheet-hl-info[data-kind]", visible: :all
      assert_no_selector ".sheet-hl-seg[data-on]", visible: :all
      assert_no_selector ".sheet-hl-btn[aria-pressed='true']", visible: :all
    end

    find("button", text: I18n.t("catalog.courses.show.revision_more")).click if has_button?(I18n.t("catalog.courses.show.revision_more"))
    within(HIGHLIGHTER) do
      click_on hl("categories.argument.name")
      assert_selector ".sheet-hl-seg[data-kind='argument'][data-on]", minimum: 1
    end
  end

  test "at 390 px the sheet has no sideways scroll, the connectors become cards and the targets are 44 px" do
    open_sheet

    with_mobile_viewport do
      visit course_path(@course.slug)
      find("button", text: I18n.t("catalog.courses.show.revision_more")).click
      await_figures

      assert_operator metric("document.documentElement.scrollWidth"), :<=, 390
      assert_operator metric("document.querySelector('.sheet-screen').scrollWidth"), :<=, metric("document.querySelector('.sheet-screen').clientWidth")
      assert_equal "block", metric("getComputedStyle(document.querySelector('.sheet-table tbody tr')).display")
      assert_equal "none", metric("getComputedStyle(document.querySelector('.sheet-table thead')).display")

      heights = metric(<<~JS)
        [ ...document.querySelectorAll(".sheet-hl-btn, .sheet-hl-all, .sheet-writing-input, .sheet-choice, .sheet-toggle") ]
          .map((element) => Math.round(element.getBoundingClientRect().height))
      JS
      assert_operator heights.size, :>=, 20
      assert_operator heights.min, :>=, 44

      find(".sheet-hl-btn[data-kind='argument']").click
      first(".sheet-hl-seg[data-kind='argument']").click
      assert_text hl("categories.argument.why")
      assert_operator metric("document.documentElement.scrollWidth"), :<=, 390
    end
  end
end
