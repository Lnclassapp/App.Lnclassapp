require "application_system_test_case"

# TR-05, TR-02 (UDR-0026): a teacher signs in for real, lands on their home, sees their classrooms and opens one. The old
# feed raised NameError as soon as the teacher had a classroom.
# RE-20 (UDR-0069): the invitation block on a phone only; the header of « Mes classes » and its ⋮ menu on one line at
# 375 px. The menu items and the bubbles are links: the controller test checks them.
class Classroom::TeacherHomeTest < ApplicationSystemTestCase
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    svt = create_material(name: "SVT", category: "science")
    level = create_level(name: "Tle")
    @classroom = create_classroom(school: @school, level:, name: "Tle D 1")
    other = create_classroom(school: @school, level:, name: "Tle D 2")
    @teacher = create_teacher(school: @school, material: svt, classrooms: [ @classroom, other ], first_name: "Yao")
    exercise = create_exercise(essential: create_essential(course: create_course(material: svt)))
    create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    create_exercise_session(student: create_student(classroom: @classroom), exercise:, status: "completed", score_percent: 75)
  end

  def tl(key, **) = I18n.t("classroom.teacher_homes.#{key}", **)
  def card(classroom) = find("li#classroom_#{classroom.public_id}")
  def box(element) = page.evaluate_script("arguments[0].getBoundingClientRect().toJSON()", element)
  # The window takes this width for the block, then gets its size back.
  def at_width(width, &) = with_mobile_viewport([ width, 900 ], &)

  # The line boxes of an element's text: one when it does not wrap.
  def line_count(element)
    page.evaluate_script(<<~JS.squish, element)
      (function (element) {
        const range = document.createRange();
        range.selectNodeContents(element);
        return new Set(Array.from(range.getClientRects(), (rect) => Math.round(rect.top))).size;
      })(arguments[0])
    JS
  end

  test "the teacher sees their classrooms, then opens one; from 1280 px, the invitation block is hidden (RE-20)" do
    sign_in_as @teacher

    assert_current_path teacher_home_path
    assert_selector "h1", text: tl("show.greeting", name: "Yao")
    assert_selector "#teacher_home_classrooms ul[data-communication--carousel-target=track] > li", count: 2
    within(card(@classroom)) do
      assert_text tl("classroom_card.students", count: 1)
      assert_text tl("classroom_card.assignments", count: 1)
      assert_text tl("classroom_card.score", score: 75)
    end
    within("#teacher_home_activity") { assert_text tl("follow_ups.empty") }
    # UDR-0077 §3.1 : sur ordinateur, les deux classes tiennent dans la bande — pas de points ; sur téléphone, elles défilent.
    assert_no_selector "#teacher_home_classrooms [data-communication--carousel-target=pager]", visible: :visible
    with_mobile_viewport do
      assert_selector "#teacher_home_classrooms [data-communication--carousel-target=pager].flex", visible: :visible
    end
    # The sidebar card « Parrainage » takes its place (UDR-0069 §3.6); the block stays in the page, hidden.
    at_width(1280) { assert_selector "#invite_colleagues", visible: :hidden }

    assert_no_page_reload do
      card(@classroom).click_link
      assert_current_path classroom_path(@classroom.public_id)
    end
    assert_selector "#classroom_link"
  end

  test "a teacher whose setup is not finished lands on the classroom declaration" do
    sign_in_as create_teacher(school: @school, onboarded: false)

    assert_current_path teacher_classrooms_path
    visit teacher_home_path
    assert_current_path teacher_classrooms_path
  end

  test "on a phone, the home, the invitation block (RE-20) and the bottom bar are visible, without horizontal scrolling" do
    sign_in_as @teacher

    with_mobile_viewport do
      visit teacher_home_path

      assert_selector "#teacher_home_classrooms ul[data-communication--carousel-target=track] > li", count: 2
      assert_selector "#invite_colleagues", visible: :visible
      assert_selector "nav.bottom-0", visible: :visible
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"

      # UDR-0069 §3.2: at 375 px, the header of « Mes classes » holds on one line with its ⋮ menu.
      at_width(375) do
        title = find("#teacher_home_classrooms h2", text: tl("show.classrooms_title"))
        menu = find("#teacher_home_classrooms button[aria-haspopup=menu][aria-label='#{tl('show.classrooms_menu')}']")
        title_box, menu_box, card_box = [ title, menu, find("#teacher_home_classrooms") ].map { box(it) }
        assert_equal 1, line_count(title), "le titre « Mes classes » passe à la ligne"
        assert menu_box["top"] < title_box["bottom"] && menu_box["bottom"] > title_box["top"], "le menu ⋮ passe sous le titre"
        assert_operator menu_box["right"], :<=, card_box["right"]
      end
    end
  end
end
