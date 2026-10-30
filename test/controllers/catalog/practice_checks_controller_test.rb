require "test_helper"

# CA-4, CA-6 à CA-9, CA-17 — ADR entraînement corrigé sans trace §4, UDR je-m-entraine-dans-la-fiche §3.4 à §3.6. « Vérifier » : le serveur juge
# les réponses d'une notion et rend le verdict puis le corrigé, dans un frame ou en page pleine, sans rien écrire.
class Catalog::PracticeChecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    @course = create_course(name: "Racines carrées", content: "")
    @notion = create_practice_notion(course: @course, questions: [ numeric_question, choice_question ])
    @student = create_student_for(@course)
    @digest = Entities::Catalog::NotionPractice.from_raw(raw_practice(numeric_question, choice_question)).digest
  end

  def frame_headers = { "Turbo-Frame" => "practice_#{@notion.slug}" }
  def pt(key, **) = I18n.t("catalog.revision_sheets.practice.#{key}", **)

  def check(answers = {}, digest: @digest, headers: frame_headers, course: @course, notion: @notion)
    post practice_check_path(course_slug: course.slug, slug: notion.slug), params: { digest:, answers: }, headers:
  end

  def right_choice
    practice = Entities::Catalog::NotionPractice.from_raw(raw_practice(numeric_question, choice_question))
    display_index(practice, practice.questions.last, 0).to_s
  end

  test "CA-4: a student gets a verdict per box and the correction in the frame, in words and not by colour alone" do
    sign_in_as @student

    check({ "0" => { "blanks" => { "0" => "4,8" } }, "1" => { "ids" => [ right_choice ] } })

    assert_response :success
    assert_select "turbo-frame#practice_#{@notion.slug}" do
      assert_select ".sheet-verdict[data-verdict='correct']", text: /#{pt('correct')}/, count: 2
      assert_select ".sheet-practice-feedback[role=status][aria-live=polite]", text: /#{Regexp.escape(pt('all_correct'))}/
      assert_select "details.sheet-practice-correction summary", text: pt("correction")
      assert_select "input[name='answers[0][blanks][0]'][value='4,8'][aria-describedby]"
    end
    assert_no_match(/<html/, response.body, "le frame seul, sans le shell")
  end

  test "CA-4: a wrong or empty box is marked aria-invalid and the saisie is kept" do
    sign_in_as @student

    check({ "0" => { "blanks" => { "0" => "5" } } })

    assert_select ".sheet-verdict[data-verdict='wrong']", text: /#{pt('wrong')}/
    assert_select ".sheet-verdict[data-verdict='blank']", text: /#{pt('blank')}/
    assert_select "input[name='answers[0][blanks][0]'][value='5'][aria-invalid=true]"
    assert_select ".sheet-practice-feedback", text: /#{Regexp.escape(pt('some_wrong'))}/
    assert_select ".sheet-practice-correction", text: /4,8 cm/
  end

  test "CA-9: without a Turbo-Frame header the same answer is a full page with the back link and the same status" do
    sign_in_as @student

    check({ "0" => { "blanks" => { "0" => "4,8" } } }, headers: {})

    assert_response :success
    assert_select "html"
    assert_select "h1", text: pt("page_title", notion: @notion.name)
    assert_select "a[href='#{course_path(@course.slug, anchor: "notion-#{@notion.slug}")}']", text: pt("back")
    assert_select "turbo-frame#practice_#{@notion.slug} .sheet-verdict[data-verdict='correct']"
    assert_select ".sheet-practice-correction", text: /4,8 cm/
  end

  test "CA-4: nothing is written, the page answers 200 and no table gains a row" do
    sign_in_as @student
    tables = ActiveRecord::Base.connection.tables - %w[schema_migrations ar_internal_metadata sessions]
    counts = -> { tables.to_h { [ it, ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{ActiveRecord::Base.connection.quote_table_name(it)}").to_i ] } }
    before = counts.call

    check({ "0" => { "blanks" => { "0" => "4,8" } } })

    assert_response :success
    assert_equal before, counts.call
  end

  test "CA-7: a changed practice answers 409 with a reload link and no form, nothing is judged" do
    sign_in_as @student

    check({ "0" => { "blanks" => { "0" => "4,8" } } }, digest: "0000000000000000")

    assert_response :conflict
    assert_select ".sheet-verdict[data-verdict='wrong']", text: pt("changed")
    assert_select "a[href='#{course_path(@course.slug, anchor: "notion-#{@notion.slug}")}']", text: pt("reload")
    assert_select "form", count: 0
    assert_select ".sheet-practice-correction", count: 0
  end

  test "CA-8: the 31st check of a minute answers 429, with the form, the saisie kept and the message" do
    sign_in_as @student
    30.times { check({}) }
    assert_response :success

    check({ "0" => { "blanks" => { "0" => "4,8" } } })

    assert_response :too_many_requests
    assert_select "[role=alert]", text: pt("rate_limited")
    assert_select "input[name='answers[0][blanks][0]'][value='4,8']"
    assert_select ".sheet-practice-questions .sheet-verdict", count: 0
    assert_select ".sheet-practice-correction", count: 0
  end

  test "CA-8: the limit is per account, another student is still served" do
    sign_in_as @student
    31.times { check({}) }
    assert_response :too_many_requests

    sign_in_as create_student_for(@course)
    check({ "0" => { "blanks" => { "0" => "4,8" } } })

    assert_response :success
    assert_select ".sheet-verdict[data-verdict='correct']"
  end

  test "CA-6: a visitor is sent to the sign-in" do
    check({})

    assert_redirected_to new_session_path
  end

  test "CA-6: a draft notion, a draft lesson, an unknown notion and a student of another level answer 404 without a hint" do
    sign_in_as @student
    draft = create_practice_notion(course: @course, name: "Brouillon de notion", status: "draft")
    check({}, notion: draft)
    assert_response :not_found

    other = create_course(name: "Autre niveau", level: create_level(name: "2nde", position: 5), content: "")
    other_notion = create_practice_notion(course: other)
    check({}, course: other, notion: other_notion)
    assert_response :not_found

    post practice_check_path(course_slug: @course.slug, slug: "inconnue"), params: { digest: @digest }, headers: frame_headers
    assert_response :not_found
  end

  test "CA-6: a teacher gets 404 for a draft notion and for a notion of a draft lesson" do
    sign_in_as create_teacher(classrooms: [])
    draft = create_practice_notion(course: @course, name: "Brouillon de notion", status: "draft")
    check({}, notion: draft)
    assert_response :not_found

    draft_course = create_course(name: "Leçon brouillon", status: "draft", content: "")
    in_draft = create_practice_notion(course: draft_course, name: "Notion d'une leçon brouillon")
    check({}, course: draft_course, notion: in_draft)
    assert_response :not_found
  end

  test "CA-6: a student gets 404 for a notion of a draft lesson, at the HTTP level" do
    sign_in_as @student
    draft_course = create_course(name: "Leçon brouillon", status: "draft", level: @course.level, content: "")
    in_draft = create_practice_notion(course: draft_course, name: "Notion d'une leçon brouillon")

    check({}, course: draft_course, notion: in_draft)

    assert_response :not_found
    assert_select ".sheet-verdict", count: 0
  end

  test "CA-6: the team may check a draft notion" do
    sign_in_as create_team_member
    draft_course = create_course(name: "Brouillon", status: "draft", content: "")
    draft = create_practice_notion(course: draft_course, status: "draft")

    check({}, course: draft_course, notion: draft, digest: Entities::Catalog::NotionPractice.from_raw(raw_practice(numeric_question)).digest)

    assert_response :success
  end

  test "a forged answers shape is judged as empty, never a 500" do
    sign_in_as @student

    check({ "0" => "x", "1" => { "ids" => "oops", "blanks" => [ 1 ] }, "99" => { "blanks" => { "0" => "4,8" } } })

    assert_response :success
    assert_select ".sheet-verdict[data-verdict='blank']", count: 2
  end

  test "an empty, unreadable or out-of-range list answer is a box to complete, never a 500" do
    notion = create_practice_notion(course: @course, name: "Liste", questions: [ select_question, select_question(blanks: 2) ])
    digest = Entities::Catalog::NotionPractice.from_raw(raw_practice(select_question, select_question(blanks: 2))).digest
    sign_in_as @student

    [ "", "abc", "99", "-1" ].each do |value|
      check({ "0" => { "blanks" => { "0" => value } }, "1" => { "blanks" => { "0" => value, "1" => value } } }, notion:, digest:)

      assert_response :success, "saisie #{value.inspect}"
      assert_select ".sheet-verdict[data-verdict='blank']", count: 3
    end
  end

  test "CA-17: a notebook question is closed with « J'ai fini » and its correction shows without any verdict" do
    notion = create_practice_notion(course: @course, name: "Cahier", questions: [ notebook_question ])
    digest = Entities::Catalog::NotionPractice.from_raw(raw_practice(notebook_question)).digest
    sign_in_as @student

    get course_path(@course.slug)
    assert_select "##{"practice_#{notion.slug}"} button[type=submit]", text: pt("done")

    check({}, notion:, digest:)

    assert_response :success
    assert_select ".sheet-verdict", count: 0
    assert_select "details.sheet-practice-correction[open]", text: /#{Regexp.escape(numeric_question["explanation"])}/
  end

  test "a notion without practice answers 404" do
    sign_in_as @student
    bare = create_essential(course: @course, name: "Sans entraînement", sheet: { "remember" => "a", "method" => [ "b" ], "example" => {}, "pitfall" => "c" })

    check({}, notion: bare)

    assert_response :not_found
  end
end
