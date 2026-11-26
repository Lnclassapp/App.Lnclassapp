require "application_system_test_case"

# TR-05, TR-02 (UDR-0026), Lot G (UDR enseignant §3.3, §3.13), accueil-enseignant-actions (UDR §3.1) : a teacher signs in for real
# and lands on their home: the band, « À suivre » with the classroom to follow, « + Ajouter une classe ». Without a classroom, the
# home asks for them (CA-L1). The rest (week, history, « Voir plus ») is read by the controller and query tests.
class Classroom::TeacherHomeTest < ApplicationSystemTestCase
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan", sigle: "LCA")
    @svt = create_material(name: "SVT", category: "science")
    @level = create_level(name: "Tle")
    @classroom = create_classroom(school: @school, level: @level, name: "Tle D 1")
  end

  def tl(key, **) = I18n.t("classroom.teacher_homes.#{key}", **)
  def card(classroom) = find("li#classroom_#{classroom.public_id}")

  test "on a phone: the band, « À suivre » with the classroom, then « + Ajouter une classe »; opening the class; no bottom bar, no side scroll" do
    teacher = create_teacher(school: @school, material: @svt, classrooms: [ @classroom ], first_name: "Yao")
    exercise = create_exercise(essential: create_essential(course: create_course(material: @svt)))
    create_assignment(classroom: @classroom, assignable: exercise, by: teacher)
    create_exercise_session(student: create_student(classroom: @classroom), exercise:, status: "completed", score_percent: 75)
    sign_in_as teacher

    with_mobile_viewport do
      visit teacher_home_path

      assert_current_path teacher_home_path
      assert_selector "header.teacher-band"
      assert_no_text "Bonjour"
      assert_no_selector "nav.bottom-0"
      assert_no_selector "nav[aria-label='#{I18n.t('shared.navigation.bottom_bar.label')}']"
      assert_no_button I18n.t("shared.navigation.bottom_bar.more")
      assert_selector "h2#teacher_home_classrooms_title", text: tl("to_follow.title")
      within(card(@classroom)) do
        assert_text "Tle D 1"
        assert_text tl("to_follow.assignments", count: 1)
      end
      assert_selector "li#add_classroom a[href='#{teacher_classrooms_path}']", text: tl("add_classroom_card.action")
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"

      assert_no_page_reload do
        card(@classroom).click_link
        assert_current_path classroom_path(@classroom.public_id)
      end
    end
  end

  test "CA-L1: a teacher without a classroom lands on the home, which asks for them, then opens the declaration; the desktop page still opens" do
    sign_in_as create_teacher(school: @school, material: @svt, onboarded: false)

    assert_current_path teacher_home_path
    within("#teacher_home_classrooms") do
      assert_text tl("add_classroom_card.empty_title")
      assert_text tl("add_classroom_card.empty_description")
      assert_no_selector "li[id^=classroom_]"
    end
    assert_no_selector "#teacher_home_week"

    click_on tl("add_classroom_card.action")

    assert_current_path teacher_classrooms_path
    visit teacher_home_path
    assert_selector "#teacher_home_classrooms"
  end
end
