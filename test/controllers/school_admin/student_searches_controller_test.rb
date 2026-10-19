require "test_helper"

# ED-60, ED-63 to ED-66 (UDR-0094): « Chercher un élève » on the direction's home, then a page of results; each result leads
# to its classroom filtered on its name; three letters at least; twenty results at most; no phone number; the direction
# only (every role of the direction space, school life included).
class SchoolAdmin::StudentSearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school
    @sixth = create_classroom(school: @school, level: create_level(name: "6ème", position: 1), name: "6ème 3")
    @aya = create_student(classroom: @sixth, first_name: "Aya", last_name: "Kouassi", contact: "0701020304")
    @admin = create_school_admin(school: @school, position: "secretary")
  end

  def ts(key, **) = I18n.t("school_admin.student_searches.#{key}", **)

  test "ED-60: the home carries the search form, a GET to the results page, outside any frame" do
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_select "#direction_home_student_search form[role=search][method=get][action='#{school_admin_student_search_path}']" \
                  "[data-turbo-frame=_top]" do
      assert_select "label[for=student_search_q]", ts("form.label")
      assert_select "input[type=search][name=q][minlength='3'][maxlength='80'][aria-describedby=student_search_hint]"
      assert_select "#student_search_hint", ts("form.hint")
    end
  end

  test "ED-60: a result names the student and the classroom, and leads to the classroom filtered on the name" do
    sign_in_as @admin

    get school_admin_student_search_path(q: "kouas")

    assert_response :success
    assert_select "#student_search_page_q[value=kouas]"
    assert_select "[aria-live=polite]", ts("show.count", count: 1)
    assert_select "#student_search_list li", 1
    assert_select "#student_result_0 a[href='#{school_admin_classroom_path(@sixth.public_id, q: "Aya Kouassi")}']" \
                  "[aria-label='#{ts("show.result_label", name: "Aya Kouassi", classroom: "6ème 3")}']", text: /6ème 3 · 6ème/

    follow_link = css_select("#student_result_0 a").sole["href"]
    get follow_link
    assert_response :success
    assert_includes response.body, "Aya Kouassi"
  end

  test "ED-63: under three letters, the hint and no list; without a term, the form alone" do
    sign_in_as @admin

    get school_admin_student_search_path(q: "ko")
    assert_select "#student_search_too_short", ts("show.too_short")
    assert_select "#student_search_list", 0

    get school_admin_student_search_path
    assert_select "#student_search_page_q:not([autofocus])"
    assert_select "#student_search_too_short, #student_search_list", 0
  end

  test "no result: the empty state and « Effacer »" do
    sign_in_as @admin

    get school_admin_student_search_path(q: "zzzz")

    assert_select "p", text: ts("show.empty")
    assert_select "a[href='#{school_admin_student_search_path}']", ts("show.clear")
  end

  test "ED-64: twenty results at most, and the sentence that says to refine" do
    25.times { create_student(classroom: @sixth, first_name: "Élève #{it}", last_name: "Koné") }
    sign_in_as @admin

    get school_admin_student_search_path(q: "kone")

    assert_select "#student_search_list li", 20
    assert_select "#student_search_truncated", ts("show.truncated", count: 20)
  end

  test "ED-64: exactly twenty results are twenty rows, without the sentence that says to refine" do
    20.times { create_student(classroom: @sixth, first_name: "Élève #{it}", last_name: "Koné") }
    sign_in_as @admin

    get school_admin_student_search_path(q: "kone")

    assert_select "#student_search_list li", 20
    assert_select "#student_search_truncated", 0
  end

  test "ED-62: a Kouassi of another school never appears, even with a forged school_id" do
    other = create_school
    create_student(classroom: create_classroom(school: other, name: "6ème 1"), first_name: "Ailleurs", last_name: "Kouassi")
    sign_in_as @admin

    [ {}, { school_id: other.id }, { school_id: other.public_id } ].each do |forged|
      get school_admin_student_search_path(q: "kouassi", **forged)

      assert_select "#student_search_list li", 1
      assert_select "#student_search_list", text: /Aya Kouassi/
      assert_select "#student_search_list", text: /Ailleurs/, count: 0
    end
  end

  test "ED-65: a phone number finds nobody, and no response carries one" do
    sign_in_as @admin

    get school_admin_student_search_path(q: "0701020304")
    assert_select "#student_search_list", 0

    get school_admin_student_search_path(q: "kouassi")
    assert_no_match(/0701020304|07 01 02 03 04/, response.body.sub(/value="[^"]*"/, ""))
  end

  test "ED-66: a teacher, a student and a team member get 403" do
    [ create_teacher(school: @school, classrooms: [ @sixth ]), @aya, create_team_member(team_role: "admin") ].each do |user|
      sign_in_as user
      get school_admin_student_search_path(q: "kouassi")

      assert_response :forbidden, user.role
      sign_out
    end
  end
end
