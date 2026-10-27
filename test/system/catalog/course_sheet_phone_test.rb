require "application_system_test_case"

# contenu-en-blocs (#318), Lot G — la fiche de cours sur téléphone : pages fluides sous 1 000 px, tableau en cartes,
# lexique en tiroir sous 640 px ; au-dessus, rien ne bouge (pages de 1 000 px pour le thème de référence).
class Catalog::CourseSheetPhoneTest < ApplicationSystemTestCase
  PHONE = [ 390, 844 ].freeze
  DESKTOP = [ 1440, 900 ].freeze

  setup do
    document = reading_course_sheet_document
    exercise = { "type" => "exercise", "title" => "Exercice 4", "prompt" => "Calculer AN.",
                 "fields" => [ { "id" => "an", "input" => "numeric", "label" => "AN =", "answer" => 3.6 } ],
                 "hint" => "Pense aux rapports.", "correction" => "AN = 3,6 cm." }
    document["pages"].first["sections"].first["blocks"] << exercise
    @course = create_course(name: "Propriétés de Thalès")
    create_course_sheet(course: @course, document:)
    sign_in_as create_student_for(@course)
  end

  teardown { page.current_window.resize_to(*DESKTOP) }

  def open_sheet(size)
    page.current_window.resize_to(*size)
    visit course_sheet_path(@course.slug)
    assert_selector ".sheet-page", minimum: 3
  end

  def metric(script) = page.evaluate_script(script)

  test "at 390 px nothing scrolls sideways and the pages are fluid" do
    open_sheet(PHONE)

    assert_operator metric("document.documentElement.scrollWidth"), :<=, 390
    assert_operator metric("document.querySelector('.sheet-screen').scrollWidth"), :<=, metric("document.querySelector('.sheet-screen').clientWidth")
    assert_operator metric("document.querySelector('.sheet-page').getBoundingClientRect().width"), :<=, 390
    assert_operator metric("document.querySelector('.sheet-page').getBoundingClientRect().height"), :<, 1000
    assert_equal "16px", metric("getComputedStyle(document.querySelector('.sheet-page-body')).paddingRight")
    assert_equal "16px", metric("getComputedStyle(document.querySelector('.sheet-page-body')).paddingTop")
  end

  test "at 390 px the table becomes one card per row, each cell labelled by its column" do
    open_sheet(PHONE)

    assert_equal "block", metric("getComputedStyle(document.querySelector('.sheet-table tbody tr')).display")
    assert_equal "none", metric("getComputedStyle(document.querySelector('.sheet-table thead')).display")
    label = metric("getComputedStyle(document.querySelector('.sheet-table td'), '::before').content")
    assert_not_equal "none", label
    assert_selector ".sheet-table td[data-label]"
  end

  test "at 390 px fields and buttons are at least 44 px tall" do
    open_sheet(PHONE)
    find(".sheet-card .sheet-btn", match: :first)

    heights = metric(<<~JS)
      [ ...document.querySelectorAll(".sheet-toggle, .sheet-btn, .sheet-input") ].map((e) => Math.round(e.getBoundingClientRect().height))
    JS
    assert_not_empty heights
    assert_operator heights.min, :>=, 44
  end

  test "at 390 px the lexicon opens as a bottom drawer and closes on outside touch, Escape and its button" do
    open_sheet(PHONE)
    drawer = ".sheet-bubble"

    click_on I18n.t("catalog.course_sheets.glossary.button")
    assert_selector drawer, visible: :visible
    box = metric("(() => { const r = document.querySelector('.sheet-bubble').getBoundingClientRect(); return [ r.left, r.right, r.bottom, r.height, innerHeight, document.documentElement.clientWidth ] })()")
    assert_in_delta 0, box[0], 1
    assert_in_delta box[5], box[1], 1
    assert_in_delta box[4], box[2], 1
    assert_operator box[3], :<=, box[4] * 0.6 + 1
    assert_equal "20px", metric("getComputedStyle(document.querySelector('.sheet-bubble')).borderTopLeftRadius")
    assert_operator metric("document.querySelector('.sheet-bubble-close').getBoundingClientRect().height"), :>=, 44
    assert_operator metric("document.querySelector('.sheet-bubble-close').getBoundingClientRect().width"), :>=, 44

    find(".sheet-bubble-close").click
    assert_no_selector drawer

    click_on I18n.t("catalog.course_sheets.glossary.button")
    assert_selector drawer
    page.send_keys(:escape)
    assert_no_selector drawer

    click_on I18n.t("catalog.course_sheets.glossary.button")
    assert_selector drawer
    find(".sheet-h1").click
    assert_no_selector drawer
  end

  test "above 640 px the lexicon stays a bubble" do
    open_sheet([ 800, 900 ])

    click_on I18n.t("catalog.course_sheets.glossary.button")
    assert_selector ".sheet-bubble"
    assert_equal 310, metric("Math.round(document.querySelector('.sheet-bubble').getBoundingClientRect().width)")
    assert_equal "8px", metric("getComputedStyle(document.querySelector('.sheet-bubble')).borderTopLeftRadius")
  end

  test "at 1 440 px nothing moved: pages are 1 000 px wide, with the A4 height and the Seyès margin" do
    open_sheet(DESKTOP)

    assert_equal 1000, metric("Math.round(document.querySelector('.sheet-page').getBoundingClientRect().width)")
    assert_operator metric("document.querySelector('.sheet-page').getBoundingClientRect().height"), :>=, 1414
    assert_equal "100px", metric("getComputedStyle(document.querySelector('.sheet-page-body')).paddingLeft")
    assert_equal "table", metric("getComputedStyle(document.querySelector('.sheet-table')).display")
  end
end
