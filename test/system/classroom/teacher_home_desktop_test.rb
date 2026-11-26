require "application_system_test_case"

# CA-G10 → Lot P1 (UDR enseignant §3.3, « Sur ordinateur »): at 1280 px the home is a page of 57 rem at most, with no yellow band
# (only the top bar is a banner). « À suivre » lists the classroom to follow, the others folded (accueil-enseignant-actions §3.1);
# the two announcements and the level bubbles are each on one line; « Cette semaine » and « Historique » are side by side, their
# titles visible; the page never scrolls sideways.
class Classroom::TeacherHomeDesktopTest < ApplicationSystemTestCase
  setup { page.current_window.resize_to(1280, 900) }
  teardown { page.current_window.resize_to(1400, 1400) }

  def rect(selector) = page.evaluate_script("(() => { const r = document.querySelector(#{selector.to_json}).getBoundingClientRect(); return { top: r.top, left: r.left, right: r.right, bottom: r.bottom, width: r.width } })()")

  test "1280 px: a 57 rem page without band, « À suivre » then the folded classrooms, two announcements, week and history side by side" do
    school = create_school(sigle: "LCA")
    svt = create_material(name: "SVT", category: "science")
    levels = [ create_level(name: "Tle", position: 9), create_level(name: "1ère", position: 8), create_level(name: "2nde", position: 7) ]
    classrooms = %w[A B C D].each_with_index.map { |suffix, index| create_classroom(school:, level: levels[index % 3], name: "Classe #{suffix}") }
    teacher = create_teacher(school:, material: svt, classrooms:)
    classrooms.each { create_student(classroom: it) }
    exercise = create_exercise(title: "Respiration", essential: create_essential(course: create_course(material: svt)))
    create_assignment(classroom: classrooms.first, assignable: exercise, by: teacher,
                      due_on: Date.current + 2, assigned_at: (Date.current + 1).in_time_zone.change(hour: 12))
    done = create_exercise(title: "Digestion", essential: create_essential(course: create_course(material: svt)))
    finished = create_assignment(classroom: classrooms.first, assignable: done, by: teacher,
                                 due_on: Date.current - 1, assigned_at: (Date.current - 2).in_time_zone.change(hour: 12))
    create_exercise_session(student: create_student(classroom: classrooms.first), exercise: done, status: "completed",
                            classroom_assignment: finished, score_percent: 80)
    author = create_team_member(second_factor: false)
    create_message(author:, title: "Première annonce", audience: "teachers")
    create_message(author:, title: "Seconde annonce", audience: "teachers")
    sign_in_as teacher

    visit teacher_home_path

    assert_selector "#teacher_home_to_follow > li[id^=classroom_]", count: 1
    assert_selector "#teacher_home_classrooms_title", text: "À suivre", visible: :visible
    page_box = rect("#teacher_home")
    assert_operator page_box["width"], :<=, 912.5, "la page dépasse 57 rem"
    assert_no_selector "#teacher_home_band, header.teacher-band", visible: :visible
    assert_selector "header", count: 1, visible: :visible # la seule bannière visible est la barre du haut, pas le bandeau jaune
    assert_no_selector "#teacher_home_other_classrooms li[id^=classroom_]", visible: :visible
    find("#teacher_home_other_classrooms summary", text: "Voir mes 3 autres classes").click
    assert_selector "#teacher_home_other_classrooms li[id^=classroom_]", count: 3, visible: :visible

    announcements = all("#student_home_announcements ul > li").map { it.rect }
    assert_equal 2, announcements.size
    assert_in_delta announcements[0].y, announcements[1].y, 1
    assert_operator announcements[1].x + announcements[1].width, :<=, rect("#student_home_announcements")["right"], "les deux annonces ne sont pas en vue"

    bubbles = all("#teacher_home_course_levels li").map { it.rect.y }
    assert_operator bubbles.size, :>=, 3
    assert_equal 1, bubbles.uniq.size, "les ronds de niveau ne tiennent pas sur une ligne"

    assert_selector "#teacher_home_week_title", visible: :visible
    assert_selector "#teacher_home_history_title", visible: :visible
    week = rect("#teacher_home_week")
    history = rect("#teacher_home_history")
    assert_in_delta week["top"], history["top"], 1, "Cette semaine et Historique ne sont pas côte à côte"
    assert_operator week["right"], :<=, history["left"]

    assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                 page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
  end
end
