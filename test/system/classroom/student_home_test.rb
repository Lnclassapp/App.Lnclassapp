require "application_system_test_case"

# CL-23, TR-04, AS-36 (UDR-0010): a signed-in student lands on their home, sees their assigned exercises with their
# badge, and « Commencer » leads to the session. The old feed raised NameError for every student with a classroom.
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

  setup do
    @classroom = create_classroom(name: "Tle D 1", join_code: "kfm37", school: create_school(name: "Lycée Classique"))
    @student = create_student(classroom: @classroom, first_name: "Aya")
    # UDR-0013, amendement du 2026-10-01 : le cours assigné est du niveau de la classe de l'élève.
    essential = create_essential(course: create_course(material: create_material(name: "SVT", category: "science"),
                                                       level: @classroom.level))
    @meiose = create_exercise(essential:, title: "La méiose")
    mitose = create_exercise(essential:, title: "La mitose")
    create_assignment(classroom: @classroom, assignable: essential)
    session = create_exercise_session(student: @student, exercise: mitose, status: "completed", score_percent: 80)
    create_badge(student: @student, exercise: mitose, level: "gold", session:)
  end

  def row(title) = find("#student_home_exercises li", text: title)
  def tl(key, **) = I18n.t("classroom.student_homes.#{key}", **)

  test "the student sees their assigned exercises and badge, then « Commencer » leads to the session" do
    sign_in_as @student

    assert_current_path student_home_path
    assert_selector "h1", text: tl("show.greeting", name: "Aya")
    assert_selector "#student_home_classroom", text: "KFM37"
    within(row("La mitose")) { assert_text tl("assigned_exercise.badge", level: I18n.t("assessment.badges.levels.gold")) }
    within("turbo-frame#student_home_recent_activity") { assert_link text: /La mitose/ }

    assert_no_page_reload do
      within(row("La méiose")) { click_on tl("assigned_exercise.start") }
      assert_current_path %r{\A/sessions/[^/]+\z}
    end
  end

  test "on a phone, the home and its bottom bar are visible, without horizontal scrolling" do
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
