require "application_system_test_case"

# TR-05, TR-02 (UDR-0026): a teacher signs in for real, lands on their home, sees their classrooms and opens one. The old
# feed raised NameError as soon as the teacher had a classroom.
class Classroom::TeacherHomeTest < ApplicationSystemTestCase
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    svt = create_material(name: "SVT", category: "science")
    level = create_level(name: "Tle")
    @classroom = create_classroom(school: @school, level:, name: "Tle D 1", join_code: "kfm37")
    other = create_classroom(school: @school, level:, name: "Tle D 2")
    @teacher = create_teacher(school: @school, material: svt, classrooms: [ @classroom, other ], first_name: "Yao")
    exercise = create_exercise(essential: create_essential(course: create_course(material: svt)))
    create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    create_exercise_session(student: create_student(classroom: @classroom), exercise:, status: "completed", score_percent: 75)
  end

  def tl(key, **) = I18n.t("classroom.teacher_homes.#{key}", **)
  def card(classroom) = find("li#classroom_#{classroom.public_id}")

  test "the teacher sees their classrooms, then opens one" do
    sign_in_as @teacher

    assert_current_path teacher_home_path
    assert_selector "h1", text: tl("show.greeting", name: "Yao")
    assert_selector "#teacher_home_classrooms > ul > li", count: 2
    within(card(@classroom)) do
      assert_text tl("classroom_card.students", count: 1)
      assert_text tl("classroom_card.assignments", count: 1)
      assert_text tl("classroom_card.score", score: 75)
    end
    assert_link tl("show.edit_classrooms"), href: teacher_classrooms_path
    within("#teacher_home_activity") { assert_text tl("show.activity_soon") }

    assert_no_page_reload do
      card(@classroom).click_link
      assert_current_path classroom_path(@classroom.public_id)
    end
    assert_text "KFM37"
  end

  test "a teacher whose setup is not finished lands on the classroom declaration" do
    sign_in_as create_teacher(school: @school, onboarded: false)

    assert_current_path teacher_classrooms_path
    visit teacher_home_path
    assert_current_path teacher_classrooms_path
  end

  test "on a phone, the home and its bottom bar are visible, without horizontal scrolling" do
    sign_in_as @teacher

    with_mobile_viewport do
      visit teacher_home_path

      assert_selector "#teacher_home_classrooms > ul > li", count: 2
      assert_selector "nav.bottom-0", visible: :visible
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end
end
