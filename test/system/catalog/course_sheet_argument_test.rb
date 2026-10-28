require "application_system_test_case"

# contenu-en-blocs (#318), Lot F, CA-11 — ce que seul un navigateur juge sur la fiche « Le texte argumentatif » : surligneurs et
# explication d'un passage, tableau des connecteurs, choix figé, rédaction et ses vérifications (sans envoi au serveur), rendu à 390 px.
# La fiche est celle des seeds, lue dans la page de la leçon (UDR-0139). Le rendu serveur est jugé par
# test/integration/catalog/course_sheet_argument_seeds_test.rb et test/views/catalog/course_sheets/argument_test.rb.
class Catalog::CourseSheetArgumentTest < ApplicationSystemTestCase
  PATH = Rails.root.join("db/seeds/data/course_sheets/texte-argumentatif.json")
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
  def check_state(name) = find("#{WRITING} li[data-check='#{name}']")[:"data-state"]

  def open_sheet
    document = JSON.parse(PATH.read)
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
      # Un passage non allumé ne répond pas.
      first(".sheet-hl-seg[data-kind='thesis']").click
      assert_text hl("idle")

      click_on hl("categories.thesis.name")
      assert_selector ".sheet-hl-btn[data-kind='thesis'][aria-pressed='true']"
      assert_selector ".sheet-hl-seg[data-kind='thesis'][data-on]", minimum: 2
      assert_no_selector ".sheet-hl-seg[data-kind='argument'][data-on]"
      assert_not_equal "rgba(0, 0, 0, 0)", metric("getComputedStyle(document.querySelector(\"#{HIGHLIGHTER} .sheet-hl-seg[data-kind='thesis']\")).backgroundColor")

      first(".sheet-hl-seg[data-kind='thesis']").click
      assert_selector ".sheet-hl-info b", text: "#{hl('categories.thesis.name')} :"
      assert_text hl("categories.thesis.why")

      click_on hl("categories.thesis.name")
      assert_no_selector ".sheet-hl-seg[data-on]"
      assert_text hl("idle")

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
      assert_equal "todo", check_state("opinion")
      assert_selector "[data-role='stats']", text: "0 mots · 0 paragraphe(s)"

      before = requests
      find(".sheet-writing-input").set(TEXT)
      assert_equal "done", check_state("opinion")
      assert_equal "done", check_state("paragraphs")
      assert_equal "done", check_state("connectors")
      assert_equal "done", check_state("example")
      assert_equal "done", check_state("question")
      assert_equal "done", check_state("conclusion")
      assert_selector "[data-role='found'] .sheet-writing-pill", text: "d'abord"
      assert_selector "[data-role='found'] .sheet-writing-pill", text: "en conclusion"
      assert_selector "[data-role='count']", text: "5"
      assert_selector "[data-role='stats']", text: "#{TEXT.split.size} mots · 3 paragraphe(s)"

      find(".sheet-writing-input").set("Un seul paragraphe, donc rien d'autre.")
      assert_equal "todo", check_state("paragraphs")
      assert_equal "todo", check_state("conclusion")
      assert_equal before, requests, "la rédaction ne part pas au serveur"
    end
    assert_no_selector "#{WRITING} form"
    assert_no_selector "#{WRITING} textarea[name]"
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
