require "application_system_test_case"

# CL-23, TR-04, AS-36 (UDR-0010, UDR-0058 §3.3): a signed-in student lands on their home, sees their assigned exercises,
# and « Commencer » leads to the session. The old feed raised NameError for every student with a classroom.
# Chantier interface-epuree, Lot A: the current home cleaned up by the sobriety rule (UDR-0057), at every size.
class Classroom::StudentHomeTest < ApplicationSystemTestCase
  # Playing a session belongs to Lot C2: until it is merged, a stand-in answers on its routes, as in
  # test/system/classroom/assignment_toggle_test.rb. A merged controller is autoloadable, so the stand-in steps aside.
  # Turbo follows the redirect asking for a stream first: the stand-in answers in HTML, with its layout, as a view would.
  unless Object.const_defined?("Assessment::ExerciseSessionsController")
    Assessment.const_set(:ExerciseSessionsController, Class.new(AuthenticatedController) do
      def create = redirect_to(exercise_session_path("stand-in"))
      def show = render(html: "session", layout: true, formats: :html)
    end)
  end

  DESKTOP_VIEWPORT = [ 1280, 900 ].freeze
  # UDR-0057 R2: the first-level blocks of the page, its header and each section of the home.
  PAGE_BLOCKS = "#main > div > :not(#student_home), #student_home > *".freeze
  # The grain of the « before » measure (Lot 0): the header, the « À faire » title, its help and each exercise line.
  TODO_BLOCKS = "#main h1, #student_home_exercises h2, #student_home_help, #student_home_exercises li".freeze

  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique"))
    @student = create_student(classroom: @classroom, first_name: "Aya")
    # UDR-0013, amendement du 2026-10-01 : le cours assigné est du niveau de la classe de l'élève.
    @course = create_course(material: create_material(name: "SVT", category: "science"), level: @classroom.level)
    @essential = create_essential(course: @course)
    @meiose = create_exercise(essential: @essential, title: "La méiose")
    mitose = create_exercise(essential: @essential, title: "La mitose")
    # ADR-0072 §4.1 : chaque exercice s'assigne seul ; assignés au même instant, ils suivent l'ordre de la fiche.
    @assigned_at = 1.hour.ago
    [ @meiose, mitose ].each { assign(it) }
    session = create_exercise_session(student: @student, exercise: mitose, status: "completed", score_percent: 80)
    create_badge(student: @student, exercise: mitose, level: "gold", session:)
  end

  def row(title) = find("#student_home_exercises li", text: title)
  def tl(key, **) = I18n.t("classroom.student_homes.#{key}", **)
  def more = I18n.t("components.reveal.more")
  def with_desktop_viewport(&) = with_mobile_viewport(DESKTOP_VIEWPORT, &)
  def assign(exercise) = create_assignment(classroom: @classroom, assignable: exercise, assigned_at: @assigned_at)

  # Four exercises in the list: La méiose, Les chromosomes, L'ADN in the order of the sheet, then La mitose, completed
  # (UDR-0062 §3.2: a completed exercise goes to the end of the list).
  def assign_four_exercises
    assign(create_exercise(essential: @essential, title: "Les chromosomes"))
    assign(create_exercise(essential: @essential, title: "L'ADN"))
  end

  test "the student sees their assigned exercises, then « Commencer » leads to the session" do
    sign_in_as @student

    assert_current_path student_home_path
    assert_selector "h1", text: tl("show.greeting", name: "Aya")
    assert_selector "#student_home_classroom", text: "Tle D 1"
    within(row("La mitose")) { assert_text "SVT" }
    within("turbo-frame#student_home_recent_activity") { assert_link text: /La mitose/ }

    assert_no_page_reload do
      within(row("La méiose")) { click_on tl("assigned_exercise.start") }
      assert_current_path %r{\A/sessions/[^/]+\z}
    end
  end

  # PRD §4, « Accueil élève — ordinateur (UDR-0058 §3.3) ».
  test "on a computer, the greeting alone, no help, lines of a title, a subject and one button, 3 lines then « Voir plus »" do
    assign_four_exercises
    sign_in_as @student

    with_desktop_viewport do
      visit student_home_path

      assert_selector "h1", text: tl("show.greeting", name: "Aya")
      within(find("h1").find(:xpath, "..")) { assert_no_selector "p" }
      assert_no_text "Lycée Classique · Tle D 1"
      within("#student_home_exercises") do
        assert_no_selector "#student_home_help"
        assert_no_text "Badges"
        assert_no_text "Maîtrise"

        assert_selector "li", count: 3
        all("li").each do |line|
          within(line) do
            assert_text "SVT"
            # UDR-0057 §2.4: the title leads to the exercise page, one tap away; the button stays beside it.
            assert_selector "a[href^='/exercises/']", count: 1
            assert_selector "a[href^='/sessions/'], button", count: 1
            assert_no_selector "a a, a button"
          end
        end
        assert_selector "li:first-child :is(#{SobrietyAssertions::PRIMARY_ACTION})", text: tl("assigned_exercise.start")
        assert_selector "li:not(:first-child) button.ui-button-secondary", count: 2
        assert_button more
      end
      assert_single_primary_action
    end
  end

  # PRD « Accueil élève », UDR-0062 §3.1 and §3.2: the most urgent exercise heads the list, with the only primary button
  # and « À rendre demain » in amber; the completed one goes last, without a date.
  test "the exercise due tomorrow heads the list, its date in amber, with the only primary button" do
    tomorrow = create_exercise(essential: @essential, title: "Les chromosomes")
    create_assignment(classroom: @classroom, assignable: tomorrow, assigned_at: @assigned_at, due_on: Date.current + 1)
    sign_in_as @student

    within("#student_home_exercises") do
      assert_selector "li", count: 3
      within("li:first-child") do
        assert_link "Les chromosomes"
        assert_selector "span.bg-warning-soft.text-warning", text: "À rendre demain"
        assert_selector ":is(#{SobrietyAssertions::PRIMARY_ACTION})", text: tl("assigned_exercise.start")
      end
      within("li:last-child") do
        assert_link "La mitose"
        assert_no_text "À rendre"
      end
    end
    assert_single_primary_action
  end

  # ADR-0072 §4.4: nothing closes once the date has passed; the late exercise says so and still starts.
  test "a late exercise says « En retard · prévu hier » and still starts" do
    late = create_exercise(essential: @essential, title: "L'ADN")
    create_assignment(classroom: @classroom, assignable: late, assigned_at: 3.days.ago, due_on: Date.yesterday)
    sign_in_as @student

    within(row("L'ADN")) { assert_selector "span.bg-warning-soft", text: "En retard · prévu hier" }

    assert_no_page_reload do
      within(row("L'ADN")) { click_on tl("assigned_exercise.start") }
      assert_current_path %r{\A/sessions/[^/]+\z}
    end
  end

  # UDR-0057 §2.4: the badge, the best score and the mastery left the line for the exercise page, one tap away.
  test "the title of a line opens the exercise page" do
    sign_in_as @student

    within(row("La méiose")) { click_link "La méiose" }

    assert_current_path exercise_path(@meiose.public_id)
    assert_selector "h1", text: "La méiose"
  end

  # PRD §4, « Règle de sobriété (UDR-0057) » at 390 × 844, then « Voir plus » reveals the 4th line without a reload.
  test "on a phone, one primary action, at most 5 blocks above the fold, every list capped at 3 lines" do
    assign_four_exercises
    gaps_course = create_course(name: "Hérédité", material: @course.material, level: @classroom.level)
    4.times { |index| create_gap(student: @student, essential: create_essential(course: gaps_course, name: "Fiche #{index + 1}")) }
    sign_in_as @student

    with_mobile_viewport do
      visit student_home_path

      assert_selector "#student_home_exercises li"
      assert_single_primary_action
      assert_blocks_above_fold PAGE_BLOCKS
      assert_blocks_above_fold TODO_BLOCKS
      # The activity is a lazy frame: it loads once scrolled into view.
      scroll_to find("turbo-frame#student_home_recent_activity")
      within("turbo-frame#student_home_recent_activity") { assert_selector "li", minimum: 1 }
      [ "#student_home_exercises", "#student_home_gaps", "turbo-frame#student_home_recent_activity" ].each do |list|
        assert_list_capped list
        within(list) { assert_button more }
      end

      within("#student_home_exercises") do
        assert_no_text "La mitose"
        # Back up from the activity, the button would stop under the sticky header of the shell: centred, it is clickable.
        scroll_to find_button(more), align: :center
        assert_no_page_reload { click_on more }
        assert_text "La mitose"
        assert_selector "li", count: 4
        assert_no_button more
      end
      assert_single_primary_action
    end
  end

  # Challenger d'interface-eleve-organisation : une ligne avec son échéance et son bouton élargissait la carte « À faire »,
  # case de la grille sans min-w-0, et toute la page avec elle (405 px pour 390).
  test "on a phone, the home and its bottom bar are visible, without horizontal scrolling" do
    Orm::ClassroomAssignment.find_by!(assignable_id: @meiose.id).update!(due_on: Time.zone.today + 4)
    @meiose.update!(title: "La méiose et la formation des gamètes chez les mammifères")
    sign_in_as @student

    with_mobile_viewport do
      visit student_home_path

      assert_selector "#student_home_exercises li", count: 2
      assert_selector "nav.bottom-0", visible: :visible
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
    end
  end
end
