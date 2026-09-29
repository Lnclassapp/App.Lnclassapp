require "application_system_test_case"

# DS-05, DS-09 (ADR-0065, UDR-0052): the school management signs in with its phone number and PIN, lands on « Travail des
# élèves », opens a classroom by its name and reads each student's work; the logo leads back. Then the same on a 390 px
# phone, from the bottom bar, without the page scrolling sideways.
class SchoolAdmin::StudentWorkTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT

  setup do
    school = create_school(name: "Lycée Moderne de Bouaké")
    @admin = create_school_admin(school:, first_name: "Adjoua")
    classroom = create_classroom(school:, level: create_level(name: "2nde", position: 5), name: "2nde C 1")
    teacher = create_teacher(school:)
    first, second = Array.new(2) { create_assignment(classroom:, by: teacher) }
    aya = create_student(classroom:, first_name: "Aya", last_name: "Bamba")
    moussa = create_student(classroom:, first_name: "Moussa", last_name: "Coulibaly")
    create_student(classroom:, first_name: "Fanta", last_name: "Diabaté")
    create_student(classroom:, first_name: "Koffi", last_name: "Diallo")
    gone = create_student(classroom:, first_name: "Parti", last_name: "Ailleurs")
    Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
    exercise = create_exercise
    [ [ aya, first, 80 ], [ aya, second, 60 ], [ moussa, first, 70 ] ].each do |student, assignment, score|
      create_exercise_session(student:, exercise:, status: "completed", score_percent: score, classroom_assignment_id: assignment.id)
    end
    @classroom = classroom
  end

  def tn(key) = I18n.t("shared.navigation.#{key}")
  def tc(key, **) = I18n.t("school_admin.classrooms.#{key}", **)

  test "DS-05, DS-09: on a desktop, the school management lands on « Travail des élèves » and opens a classroom" do
    sign_in_as @admin

    assert_student_work_journey(nav: "aside nav")
  end

  test "DS-05, DS-09: on a 390 px phone, the same journey from the bottom bar, without horizontal scroll" do
    with_mobile_viewport do
      sign_in_as @admin

      assert_student_work_journey(nav: "nav.bottom-0")
      assert_no_horizontal_scroll
    end
  end

  private

  def assert_student_work_journey(nav:)
    assert_selector "main#main", wait: SIGN_IN_WAIT
    assert_current_path school_admin_classrooms_path
    within(nav) do
      assert_selector "a[href]", count: 2
      assert_selector "a[aria-current=page][href='#{school_admin_classrooms_path}']", text: tn(:student_work)
      assert_selector "a[href='#{school_admin_teachers_path}']", text: tn(:teachers)
    end
    assert_selector "h1", text: tc("index.title")
    within("#classroom_#{@classroom.public_id}") do
      assert_selector "td", text: "4"
      assert_selector "td", text: "38 %"
    end
    assert_no_horizontal_scroll

    click_link "2nde C 1"

    assert_current_path school_admin_classroom_path(@classroom.public_id)
    assert_selector "h1", text: "2nde C 1"
    within(nav) { assert_selector "a[aria-current=page]", text: tn(:student_work) }
    rows = all("#classroom_students tbody tr").map { |row| row.all("th, td").map(&:text) }
    assert_equal [ [ "Aya Bamba", "2 / 2" ], [ "Moussa Coulibaly", "1 / 2" ], [ "Fanta Diabaté", "0 / 2" ], [ "Koffi Diallo", "0 / 2" ] ],
                 rows.map { it.first(2) }
    assert_equal [ "70 %", "70 %" ], rows.first(2).map(&:last)
    rows.last(2).each { assert_match(/\A—/, it.last) }
    assert_no_text "Parti"
    assert_no_horizontal_scroll

    find("header a", match: :first).click

    assert_current_path school_admin_classrooms_path
  end

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end
end
