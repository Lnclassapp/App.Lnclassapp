require "application_system_test_case"

# CA-D1, CA-D2, CA-D8, CA-D9 (mvp-teacher-student, Lot D), at 390 px: the one system test of the student home. The band replaces the
# header, the card straddles it and says the next gesture, the grid has seven rounds, the history arrives in its frame. The states of
# the card, the order of the exercises and the rest are proved in the query, controller and integration tests
# (test/infrastructure/queries/classroom/student_home_query_test.rb, test/controllers/classroom/student_homes_controller_test.rb,
# test/integration/identity/student_header_test.rb). The computer (CA-D10, Lot O1) has its own short test at 1440 px.
class Classroom::StudentHomeTest < ApplicationSystemTestCase
  DESKTOP_VIEWPORT = [ 1280, 900 ].freeze
  WIDE_VIEWPORT = [ 1440, 1000 ].freeze

  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique", sigle: "LCA"))
    @student = create_student(classroom: @classroom, first_name: "Aya")
    course = create_course(material: create_material(name: "SVT", category: "science"), level: @classroom.level)
    essential = create_essential(course:)
    @late = create_exercise(essential:, title: "La méiose")
    create_assignment(classroom: @classroom, assignable: @late, assigned_at: 4.days.ago, due_on: Date.current - 2)
    create_assignment(classroom: @classroom, assignable: create_exercise(essential:, title: "La mitose"),
                      assigned_at: 1.hour.ago, due_on: Date.current + 3)
    done = create_exercise(essential:, title: "Les gamètes")
    create_assignment(classroom: @classroom, assignable: done, assigned_at: 1.hour.ago)
    create_exercise_session(student: @student, exercise: done, status: "completed", score_percent: 80)
    sign_in_as @student
  end

  def tl(key, **) = I18n.t("classroom.student_homes.#{key}", **)

  test "on a phone: the band, the card on the late exercise, the grid of seven, the history; no sideways scroll; nothing broken on a computer" do
    with_mobile_viewport do
      visit student_home_path

      # Band and header: the blue band is there, the sticky header is not (the band carries the avatar and the help).
      assert_selector "header.student-band a[aria-label]", visible: :visible
      assert_selector "header.student-band a", text: I18n.t("shared.navigation.home_band.help")
      assert_no_selector "header.sticky", visible: :visible

      # The card straddles the band, says what to do now, and has the only primary button.
      within "#student_next_step" do
        assert_selector "#student_next_step_title", text: "La méiose"
        assert_text(/En retard/)
        assert_link text: /LCA/, href: student_classroom_path
        assert_button tl("next_step.late.start")
        assert_selector "[role=progressbar][aria-valuenow='1'][aria-valuemax='3']"
      end
      band = find("header.student-band")
      assert_operator find("#student_next_step").rect.y, :<, band.rect.y + band.rect.height
      assert_equal 1, all("#student_home .ui-button-primary").size

      # The grid: four columns, six subjects at most plus « Inviter », a dot on the subject that is late (CA-D8).
      assert_selector "nav#student_subjects a#subject_svt .bg-warning-dot", visible: :all
      assert_selector "nav#student_subjects a#subject_invite"
      columns = page.evaluate_script("getComputedStyle(document.querySelector('#student_subjects ul')).gridTemplateColumns.split(' ').length")
      assert_equal 4, columns

      # The history arrives in its lazy frame.
      scroll_to find("#student_history")
      within("#student_history") { assert_selector "li", text: "Les gamètes" }
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"

      click_on tl("next_step.late.start")
      assert_current_path %r{\A/sessions/[^/]+\z}
    end

    with_mobile_viewport(DESKTOP_VIEWPORT) do
      visit student_home_path

      assert_selector "header.sticky", visible: :visible
      assert_no_selector "header.student-band", visible: :visible
      assert_selector "#student_next_step_title", text: "La méiose"
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end

  # CA-D10 (Lot O1): the page is only measured; the markup rules are in test/controllers/classroom/student_homes_controller_test.rb.
  test "on a computer (1440 px): 912 px beside a sidebar without profile card, no band, seven subjects on a line, two announcements, mist page" do
    create_message(author: create_team_member(second_factor: false), title: "Rentrée", audience: "all", published_at: 1.hour.ago)
    create_message(author: create_school_admin(school: @classroom.school, gender: "female", last_name: "Kamaté"), title: "Parents",
                   school: @classroom.school, published_at: 2.hours.ago)

    with_mobile_viewport(WIDE_VIEWPORT) do
      visit student_home_path

      assert_selector "header.sticky", visible: :visible
      assert_no_selector "header.student-band", visible: :visible
      assert_no_selector "aside .ui-avatar", visible: :all
      assert_selector "aside nav a", count: 3

      assert_operator find("#student_home").rect.width, :<=, 912
      assert_operator find("#student_home").rect.x, :>=, find("aside").rect.width
      tops = %w[#student_next_step #student_subjects #student_home_announcements #student_history].map { find(it).rect.y }
      assert_equal tops.sort, tops, "les sections s'empilent dans l'ordre"
      assert_equal 7, page.evaluate_script("getComputedStyle(document.querySelector('#student_subjects ul')).gridTemplateColumns.split(' ').length")
      assert_selector "#student_subjects h2", text: I18n.t("classroom.student_homes.subjects.label"), visible: :visible

      track = find("#student_home_announcements ul")
      cards = all("#student_home_announcements li").map { it.rect }
      assert_equal 2, cards.count { it.x + it.width <= track.rect.x + track.rect.width + 1 }, "deux annonces visibles"
      assert_equal "rgb(244, 248, 251)", page.evaluate_script("getComputedStyle(document.querySelector('body > div.fixed.bg-mist')).backgroundColor")
      assert_equal "rgb(255, 255, 255)", page.evaluate_script("getComputedStyle(document.querySelector('#student_next_step')).backgroundColor")
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end
end
