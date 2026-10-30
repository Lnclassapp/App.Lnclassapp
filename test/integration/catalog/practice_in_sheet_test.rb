require "test_helper"

# CA-1, CA-2, CA-3, CA-16, CA-17, CA-18 — UDR je-m-entraine-dans-la-fiche §3.1, §3.2 : « Je m'entraîne » dans la page de la leçon.
class Catalog::PracticeInSheetTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Racines carrées", content: "")
    @student = create_student_for(@course)
  end

  def pt(key, **) = I18n.t("catalog.revision_sheets.practice.#{key}", **)
  def sheet_t(key) = I18n.t("catalog.revision_sheets.sheet.#{key}")

  def open_course(user = @student)
    sign_in_as user
    get course_path(@course.slug)
    assert_response :success
  end

  test "CA-1: the practice sits between the example and the pitfall, titled « Je m'entraîne », in the notion section" do
    create_practice_notion(course: @course, questions: [ two_blank_numeric_question, choice_question ])

    open_course

    section = css_select("section.sheet-section").first
    labels = section.css(".sheet-box-label, .sheet-card-title").map { it.text.strip }
    assert_equal [ sheet_t("remember"), sheet_t("method"), sheet_t("example"), pt("title"), sheet_t("pitfall") ], labels
    assert_select "section.sheet-section .sheet-card[data-tone=practice] turbo-frame[id^=practice_] form" do
      assert_select "ol.sheet-practice-questions > li", 2
      assert_select "button[type=submit]", text: pt("check")
    end
    assert_select ".sheet-practice-correction", count: 0
  end

  test "CA-2: a notion without practice keeps its four blocks and shows no trace of the practice" do
    notion = revision_notion("Sans entraînement")
    create_essential(course: @course, name: notion["name"],
                     sheet: { "remember" => notion["remember"], "method" => notion["method"], "example" => notion["example"], "pitfall" => notion["pitfall"] })

    open_course

    labels = css_select("section.sheet-section").first.css(".sheet-box-label, .sheet-card-title").map { it.text.strip }
    assert_equal [ sheet_t("remember"), sheet_t("method"), sheet_t("example"), sheet_t("pitfall") ], labels
    assert_select "[data-tone=practice]", count: 0
    assert_no_match(/#{Regexp.escape(pt('title'))}/, response.body)
  end

  test "CA-3: neither a student, a teacher nor the team gets the expected value, the right proposition or the explanation" do
    create_practice_notion(course: @course, questions: [ numeric_question, choice_question ])
    classroom = Orm::Classroom.find_by!(level: @course.level)
    teacher = create_teacher(classrooms: [ classroom ])

    [ @student, teacher, create_team_member ].each do |user|
      open_course(user)

      assert_no_match(/4,8/, css_select("[data-tone=practice]").to_s)
      assert_not_includes response.body, PracticeHelper::EXPLANATION
      assert_select "[data-tone=practice] [data-verdict]", count: 0
      assert_select "[data-tone=practice] .sheet-practice-correction", count: 0
    end
  end

  test "CA-16: the hint is a closed details in the page, readable without a request" do
    create_practice_notion(course: @course, questions: [ two_blank_numeric_question ])

    open_course

    assert_select "details.sheet-practice-hint:not([open])" do
      assert_select "summary", text: pt("hint")
      assert_select "p", text: "Écris l'égalité des trois rapports."
    end
  end

  test "CA-17: a written question has « J'ai fini » and the model answer opens without any verdict" do
    notion = create_practice_notion(course: @course, questions: [ written_question ])
    digest = Entities::Catalog::NotionPractice.from_raw(raw_practice(written_question)).digest
    open_course
    assert_select "button[type=submit]", text: pt("done")
    assert_select "button[type=submit]", text: pt("check"), count: 0

    post practice_check_path(course_slug: @course.slug, slug: notion.slug), params: { digest:, answers: { "0" => { "text" => "Parce que." } } },
                                                                              headers: { "Turbo-Frame" => "practice_#{notion.slug}" }

    assert_response :success
    assert_select "details.sheet-practice-correction[open]", text: /#{Regexp.escape(PracticeHelper::EXPLANATION)}/
    assert_select ".sheet-verdict", count: 0
  end

  test "CA-18: a practice is not an exercise : no exercise row, and « Prépare interros » does not list it" do
    create_practice_notion(course: @course, questions: [ numeric_question ])

    assert_equal 0, Orm::Exercise.where(course: @course).count

    open_course

    assert_select "#prepare-interros [data-tone=practice]", count: 0
    assert_select "#prepare-interros", text: /Dans le triangle ABC/, count: 0
  end

  test "CA-10: a long notion folds the whole practice block when the cut falls before it" do
    long = revision_notion("Notion longue").merge("remember" => Array.new(160) { "mot" }.join(" "))
    create_essential(course: @course, name: long["name"], sheet: { "remember" => long["remember"], "method" => long["method"], "example" => long["example"],
                                                                 "pitfall" => long["pitfall"], "practice" => raw_practice(numeric_question) })

    open_course

    assert_select "[data-tone=practice][data-catalog--revision-more-target=rest]", count: 1
  end
end
