require "application_system_test_case"

# CA-6 dans un navigateur — ce que seul un navigateur juge : « Vérifier » rend le verdict dans le frame sans recharger la page, la saisie
# est gardée, « Correction » n'existe qu'après, la fiche tient à 390 px. Le rendu serveur est jugé par test/controllers/catalog/practice_checks_controller_test.rb.
class Catalog::PracticeInSheetSystemTest < ApplicationSystemTestCase
  setup do
    @course = create_course(name: "Racines carrées", content: "", sheet_theme: "teal")
    @student = create_student_for(@course)
    @notion = create_practice_notion(course: @course, questions: [ numeric_question, choice_question ])
  end

  def pt(key) = I18n.t("catalog.revision_sheets.practice.#{key}")
  def box(index, question = 0) = find("input[name='answers[#{question}][blanks][#{index}]']")
  def no_sideways_scroll? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  test "the student checks her box in place : verdict, saisie kept, correction only afterwards, no reload" do
    sign_in_as @student
    visit course_path(@course.slug, anchor: "fiche-de-revision")

    within "turbo-frame#practice_#{@notion.slug}" do
      assert_no_selector "summary", text: pt("correction")
      assert_no_selector ".sheet-practice-questions .sheet-verdict"
      box(0).fill_in(with: "5")
      assert_no_page_reload { click_button pt("check") }

      assert_selector ".sheet-verdict[data-verdict=wrong]", text: pt("wrong")
      assert_selector ".sheet-verdict[data-verdict=blank]", text: pt("blank")
      assert_equal "5", box(0).value
      assert_selector "summary", text: pt("correction")
      box(0).fill_in(with: "4,8")
      click_button pt("check")
      assert_selector ".sheet-verdict[data-verdict=correct]", text: pt("correct")
      find("summary", text: pt("correction")).click
      assert_text "4,8 cm"
    end
    assert_current_path course_path(@course.slug)
  end

  test "a two-box question gets one verdict per box" do
    notion = create_practice_notion(course: create_course(name: "Thalès", content: "", level: @course.level), questions: [ two_blank_numeric_question ])
    sign_in_as @student
    visit course_path(notion.course.slug, anchor: "fiche-de-revision")

    box(0).fill_in(with: "4,8")
    box(1).fill_in(with: "5")
    click_button pt("check")

    assert_selector ".sheet-verdict[data-verdict=correct]", text: pt("correct")
    assert_selector ".sheet-verdict[data-verdict=wrong]", text: pt("wrong")
    assert_equal "5", box(1).value
  end

  test "on a phone the practice fits the screen, its boxes are 48 px targets, before and after « Vérifier »" do
    sign_in_as @student

    with_mobile_viewport do
      visit course_path(@course.slug, anchor: "fiche-de-revision")
      assert no_sideways_scroll?, "la page défile sur le côté"
      assert_operator box(0).native.size.height, :>=, 48
      assert_operator find_button(pt("check")).native.size.height, :>=, 48
      box(0).fill_in(with: "4,8")
      click_button pt("check")
      assert_selector ".sheet-verdict", text: pt("correct")
      assert no_sideways_scroll?, "la page défile sur le côté après Vérifier"
    end
  end
end
