require "application_system_test_case"

# AD-02 to AD-13, AD-17, AD-20 to AD-22 (UDR-0074), the nominal journey of the PRD §3: the direction signs in on its home,
# reads its school card and its alerts, opens the level whose bubble carries a dot, then the red classroom, and comes back
# to the level; the recent activity loads after the page. The error path: the address of a level without a classroom is a
# 404. The same journey on a 390 px phone, from the bottom bar, without the page scrolling sideways.
class SchoolAdmin::DirectionHomeTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT

  setup do
    school = create_school(name: "Lycée Moderne de Bouaké")
    @admin = create_school_admin(school:, first_name: "Adjoua")
    third = create_level(name: "3ème", position: 4, cycle: "first")
    sixth = create_level(name: "6ème", position: 1, cycle: "first")
    @good = create_classroom(school:, level: third, name: "3ème 1")
    @red = create_classroom(school:, level: third, name: "3ème 2")
    create_classroom(school:, level: sixth, name: "6ème 1")
    teacher = create_teacher(school:, classrooms: [ @good, @red ], gender: "male", last_name: "Kouassi")
    exercise = create_exercise(title: "Les fractions")
    # 3ème 1: 2 students, both hand in (100 %, green) ; 3ème 2: 3 students, one hands in (33 %, red) ; 3ème: 3 / 5 = 60 %.
    { @good => 2, @red => 1 }.each do |classroom, handing_in|
      assignment = create_assignment(classroom:, assignable: exercise, by: teacher)
      students = Array.new(classroom == @good ? 2 : 3) { create_student(classroom:) }
      students.first(handing_in).each do |student|
        create_exercise_session(student:, exercise:, status: "completed", score_percent: 70, classroom_assignment_id: assignment.id)
      end
    end
  end

  def tn(key) = I18n.t("shared.navigation.#{key}")

  test "AD-02 to AD-13, AD-17: on a desktop, the direction goes from its home to a level, then to its red classroom and back" do
    sign_in_as @admin

    assert_journey(nav: "aside nav")
    assert_level_not_found
  end

  test "AD-20, AD-21: on a 390 px phone, the same journey from the bottom bar, without horizontal scroll" do
    with_mobile_viewport do
      sign_in_as @admin

      assert_journey(nav: "nav.bottom-0")
    end
  end

  # Constat du challenger (phase 5, R1) : à 360 px — le plus petit Android courant —, « enseignants » sortait de sa tuile.
  test "AD-21: on a 360 px phone, each figure's label stays inside its tile" do
    with_mobile_viewport([ 360, 740 ]) do
      sign_in_as @admin
      assert_selector "#direction_home_figures li", count: 3, wait: SIGN_IN_WAIT

      overflows = page.evaluate_script(<<~JS)
        [...document.querySelectorAll("#direction_home_figures li")].map((tile) => {
          const box = tile.getBoundingClientRect();
          return [...tile.querySelectorAll("span")].some((label) => {
            const inner = label.getBoundingClientRect();
            return label.scrollWidth > label.clientWidth || inner.right > box.right + 0.5 || inner.left < box.left - 0.5;
          });
        })
      JS
      assert_equal [ false, false, false ], overflows
      assert_no_horizontal_scroll
    end
  end

  private

  def assert_journey(nav:)
    assert_selector "h1", text: "Bonjour, Adjoua", wait: SIGN_IN_WAIT
    assert_current_path school_admin_classrooms_path
    within(nav) { assert_selector "a[aria-current=page][href='#{school_admin_classrooms_path}']", text: tn(:home) }
    within("#direction_home_school") do
      assert_text "Lycée Moderne de Bouaké"
      assert_selector "#alert_without_teacher", text: "6ème 1"
      assert_selector "#alert_red_signal", text: "3ème 2"
    end
    assert_selector "#level_6eme"
    assert_selector "#level_3eme span.bg-signal-yellow"
    # The activity frame is lazy: on a phone it loads once scrolled into view, never before (data is costly).
    scroll_to find("#direction_home_activity")
    within("#direction_home_activity_feed") { assert_text "M. Kouassi a donné « Les fractions » à 3ème 1" }
    assert_no_horizontal_scroll

    find("#level_3eme").click

    assert_current_path school_admin_level_path("3eme")
    assert_selector "h1", text: "3ème"
    within(nav) { assert_selector "a[aria-current=page]", text: tn(:home) }
    assert_selector "#classroom_#{@good.public_id} span.bg-signal-green"
    within("#classroom_#{@red.public_id}") do
      assert_selector "span.bg-signal-red"
      assert_text "33 %"
    end
    assert_selector "#signal_legend"
    assert_no_horizontal_scroll

    find("#classroom_#{@red.public_id} a").click

    assert_current_path school_admin_classroom_path(@red.public_id)
    assert_selector "h1", text: "3ème 2"
    within("main nav[aria-label='#{I18n.t('components.back_link.label')}']") { click_link "3ème" }

    assert_current_path school_admin_level_path("3eme")
  end

  def assert_level_not_found
    visit school_admin_level_path("tle")

    assert_text I18n.t("errors.not_found.title")
  end

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end
end
