require "test_helper"

# DS-07, DS-09, DS-10, DS-11 (ADR-0065, UDR-0052): « Travail des élèves » and the page of a classroom, read by the school
# management of its own school only. Another school's classroom is a 404, any other role a 403, a visitor signs in first.
class SchoolAdmin::ClassroomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @admin = create_school_admin(school: @school)
    @level = create_level(name: "2nde", position: 5)
    @classroom = create_classroom(school: @school, level: @level, name: "2nde C 1")
    @other = create_classroom(school: create_school(name: "Lycée Classique d'Abidjan"), level: @level, name: "Tle D 9")
    create_student(classroom: @other, first_name: "Intrus", last_name: "Ailleurs")
  end

  def tc(key, **) = I18n.t("school_admin.classrooms.#{key}", **)
  def pages = [ school_admin_classrooms_path, school_admin_classroom_path(@classroom.public_id) ]

  def handed_in(student, assignment, score)
    create_exercise_session(student:, status: "completed", score_percent: score, classroom_assignment_id: assignment.id)
  end

  test "DS-11: a student, a teacher, a team member and a detached school admin receive 403" do
    [ create_student, create_teacher(school: @school), create_team_member, create_user(role: "school_admin") ].each do |outsider|
      sign_in_as outsider

      pages.each do |path|
        get path
        assert_response :forbidden, "#{outsider.role} on #{path}"
      end
      sign_out
    end
  end

  test "DS-11: a visitor is sent to sign in" do
    pages.each do |path|
      get path
      assert_redirected_to new_session_path
    end
  end

  test "DS-10: another school's classroom, an unknown one and an archived one give 404" do
    archived = create_classroom(school: @school, level: @level, name: "2nde C 9", status: "archived")
    sign_in_as @admin

    [ @other.public_id, "inconnu", archived.public_id ].each do |public_id|
      get school_admin_classroom_path(public_id)
      assert_response :not_found, public_id
    end
  end

  test "DS-07, DS-10: the list shows each classroom of the school with its figures, never another school's" do
    teacher = create_teacher(school: @school)
    given = create_assignment(classroom: @classroom, by: teacher)
    create_assignment(classroom: @classroom, by: teacher)
    aya = create_student(classroom: @classroom)
    3.times { create_student(classroom: @classroom) }
    handed_in(aya, given, 80)
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_response :success
    assert_select "h1", count: 1, text: tc("index.title")
    assert_select "p", text: tc("index.subtitle", school: "Lycée Moderne de Bouaké",
                                                  year: Entities::Classroom::SchoolYear.current(Date.current))
    assert_select "nav a[aria-current=page]", text: I18n.t("shared.navigation.student_work")
    assert_select "#student_work table caption.sr-only", text: tc("index.caption")
    assert_select "#student_work th[scope=col]", count: 5
    assert_select "tr#classroom_#{@classroom.public_id}" do
      assert_select "th[scope=row] a[href=?]", school_admin_classroom_path(@classroom.public_id), text: "2nde C 1"
      assert_select "th[scope=row] span", text: "2nde"
      assert_select "td", text: "4"
      assert_select "td", text: "2"
      assert_select "td", text: "13 %"
      assert_select "td span[aria-hidden=true]", text: "—"
      assert_select "td span.sr-only", text: tc("not_computed")
    end
    assert_select "p", text: tc("index.average_rule")
    assert_select "tbody tr", count: 1
    assert_no_match(/Tle D 9|Intrus|Lycée Classique/, response.body)
  end

  test "the list of a school without classroom this year says so" do
    @classroom.destroy!
    sign_in_as @admin

    get school_admin_classrooms_path

    assert_response :success
    assert_select "#student_work table", count: 0
    assert_select "#student_work", text: /#{tc('index.empty')}/
  end

  test "DS-09: the classroom page shows its figures, then each student handed in over given and their average" do
    teacher = create_teacher(school: @school)
    given = create_assignment(classroom: @classroom, by: teacher)
    create_assignment(classroom: @classroom, by: teacher)
    aya = create_student(classroom: @classroom, first_name: "Aya", last_name: "Bamba")
    create_student(classroom: @classroom, first_name: "Koffi", last_name: "Diallo")
    handed_in(aya, given, 72)
    sign_in_as @admin

    get school_admin_classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "a[href=?]", school_admin_classrooms_path, text: tc("show.back")
    assert_select "h1", count: 1, text: "2nde C 1"
    assert_select "p", text: tc("show.subtitle", level: "2nde", count: 2)
    assert_select "nav a[aria-current=page]", text: I18n.t("shared.navigation.student_work")
    assert_select "ul#classroom_figures li", count: 3
    assert_select "ul#classroom_figures li", text: /2\s+#{tc('show.figures.assignments')}/
    assert_select "ul#classroom_figures li", text: /25 %\s+#{tc('show.figures.submission_rate')}/
    assert_select "#classroom_students caption.sr-only", text: tc("show.caption", classroom: "2nde C 1")
    assert_select "#classroom_students th[scope=col]", count: 3
    assert_select "tr#student_0" do
      assert_select "th[scope=row]", text: "Aya Bamba"
      assert_select "td", text: "1 / 2"
      assert_select "td", text: "72 %"
    end
    assert_select "tr#student_1" do
      assert_select "th[scope=row]", text: "Koffi Diallo"
      assert_select "td", text: "0 / 2"
      assert_select "td span[aria-hidden=true]", text: "—"
    end
    assert_no_match(/#{aya.public_id}|#{aya.contact}/, response.body)
    assert_select "main form, main button", count: 0
  end

  test "a classroom without student keeps its figures and says it is empty" do
    sign_in_as @admin

    get school_admin_classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "ul#classroom_figures li", count: 3
    assert_select "#classroom_students table", count: 0
    assert_select "#classroom_students", text: /#{tc('show.empty')}/
  end
end
