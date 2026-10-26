require "application_system_test_case"

# CA-G10 → Lot P1 (UDR enseignant §3.3, « Sur ordinateur »): at 1280 px the home is a page of 57 rem at most, with no yellow band
# (only the top bar is a banner). The class cards are a one-line carousel of 16.5 rem cards, the fourth cut at the edge, « + Ajouter
# une classe » last and the pager shown; the two announcements and the level bubbles are each on one line; « Cette semaine » and
# « Historique » are side by side, their titles visible; the page never scrolls sideways.
class Classroom::TeacherHomeDesktopTest < ApplicationSystemTestCase
  setup { page.current_window.resize_to(1280, 900) }
  teardown { page.current_window.resize_to(1400, 1400) }

  def rect(selector) = page.evaluate_script("(() => { const r = document.querySelector(#{selector.to_json}).getBoundingClientRect(); return { top: r.top, left: r.left, right: r.right, bottom: r.bottom, width: r.width } })()")

  test "1280 px: a 57 rem page without band, a carousel of 16.5 rem class cards with the fourth cut, two announcements, week and history side by side" do
    school = create_school(sigle: "LCA")
    svt = create_material(name: "SVT", category: "science")
    levels = [ create_level(name: "Tle", position: 9), create_level(name: "1ère", position: 8), create_level(name: "2nde", position: 7) ]
    classrooms = %w[A B C D].each_with_index.map { |suffix, index| create_classroom(school:, level: levels[index % 3], name: "Classe #{suffix}") }
    teacher = create_teacher(school:, material: svt, classrooms:)
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

    assert_selector "#teacher_home_classrooms li[id^=classroom_]", count: 4
    page_box = rect("#teacher_home")
    assert_operator page_box["width"], :<=, 912.5, "la page dépasse 57 rem"
    assert_no_selector "#teacher_home_band, header.teacher-band", visible: :visible
    assert_selector "header", count: 1, visible: :visible # la seule bannière visible est la barre du haut, pas le bandeau jaune

    track = "#teacher_home_classrooms ul[data-communication--carousel-target='track']"
    cards = all("#{track} > li").map { it.rect }
    assert_equal 5, cards.size
    assert_equal [ cards[0].y ], cards.map(&:y).uniq, "les cartes ne sont pas sur une ligne"
    assert_in_delta 264 + 12, cards[1].x - cards[0].x, 1, "les cartes n'ont pas 16,5 rem"
    track_box = rect(track)
    assert_operator cards[2].x + cards[2].width, :<=, track_box["right"] + 1, "la troisième carte est coupée"
    assert_operator cards[3].x, :<, track_box["right"], "la quatrième carte n'est pas visible"
    assert_operator cards[3].x + cards[3].width, :>, track_box["right"] + 1, "la quatrième carte n'est pas coupée au bord"
    assert_selector "#teacher_home_classrooms ul > li:last-child#add_classroom"
    assert_selector "#teacher_home_classrooms [data-communication--carousel-target='pager'].flex", visible: :visible

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
