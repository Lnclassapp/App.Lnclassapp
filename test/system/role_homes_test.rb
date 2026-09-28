require "application_system_test_case"

# TR-04, TR-05, TR-09 (chantier queries-constantes-orm-disparues, plan Lot E): for every role, a real sign-in, the home
# without error, then every destination of the shell opened by its real link, and the real « Se déconnecter ». A
# destination whose route is not drawn in V1 renders as an inactive entry (NavigationHelper): it is checked as inactive,
# never followed. The data holds one assignment of each kind: on an empty base, the old feeds passed green by mistake.
class RoleHomesTest < ApplicationSystemTestCase
  setup do
    svt = create_material(name: "SVT", category: "science")
    tle = create_level(name: "Tle", position: 7)
    drena = create_drena(name: "Abidjan 1")
    school = create_school(drena:, name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school:, level: tle, name: "Tle D 1", join_code: "kfm37")
    @teacher = create_teacher(school:, material: svt, classrooms: [ @classroom ], first_name: "Yao")
    @student = create_student(classroom: @classroom, first_name: "Aya")
    course = create_course(name: "Génétique et évolution", level: tle, material: svt)
    essential = create_essential(course:, name: "La méiose")
    exercise = create_exercise(essential:, title: "Exercice sur la méiose")
    [ course, essential, exercise ].each { |assignable| create_assignment(classroom: @classroom, assignable:, by: @teacher) }
    session = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 80)
    create_badge(student: @student, exercise:, level: "gold", session:)
    create_course(name: "Brouillon de l'équipe", level: tle, material: svt, status: "draft")
    create_import_report(kind: "schools", status: "completed", total_count: 1, imported_count: 1)
  end

  def tn(key) = I18n.t("shared.navigation.#{key}")

  test "the student reaches their home, then every destination of their navigation" do
    sign_in_as @student

    assert_home student_home_path, greeting: I18n.t("classroom.student_homes.show.greeting", name: "Aya")
    assert_text "KFM37"
    assert_navigation active: { home: student_home_path, courses: courses_path, classroom: student_classroom_path }
    assert_signs_out
  end

  test "the teacher reaches their home, then every destination of their navigation" do
    sign_in_as @teacher

    assert_home teacher_home_path, greeting: I18n.t("classroom.teacher_homes.show.greeting", name: "Yao")
    assert_navigation active: { home: teacher_home_path, classrooms: teacher_classrooms_path, courses: courses_path }
    assert_signs_out
  end

  test "the team member reaches their home, then every destination of their navigation; the dashboard is inactive" do
    sign_in_as create_team_member(first_name: "Awa")

    assert_home team_home_path, greeting: I18n.t("teams.homes.show.greeting", name: "Awa")
    assert_navigation active: { home: team_home_path, courses: courses_path, schools: schools_path, imports: teams_imports_path },
                      inactive: %i[dashboard]
    assert_signs_out
  end

  # school_admin is V2 (HomeDestination): the account lands on the pending screen, in the shell of its role, whose four
  # destinations are all inactive.
  test "the school admin lands on the pending screen, with every destination of their navigation inactive" do
    sign_in_as create_user(role: "school_admin", first_name: "Koffi")

    assert_home pending_account_path
    assert_selector "main", text: I18n.t("identity.pending_accounts.show.other.title")
    assert_navigation inactive: %i[home classrooms teachers students]
    assert_signs_out
  end

  test "on a phone, the student opens every destination from the bottom bar" do
    sign_in_as @student

    with_mobile_viewport do
      assert_navigation active: { home: student_home_path, courses: courses_path, classroom: student_classroom_path },
                        nav: "nav.bottom-0"
    end
  end

  private

  # The page arrived in the shell, not on an error page (rendered in the bare layout): the sidebar is there.
  def assert_home(path, greeting: nil)
    assert_current_path path
    assert_selector "aside nav"
    assert_selector "h1", text: greeting if greeting
  end

  # Each active destination is a real link, clicked from the navigation; the page it opens marks it current. An inactive
  # one has no href and aria-disabled. The logo, from the last page, leads back home.
  def assert_navigation(active: {}, inactive: [], nav: "aside nav")
    within(nav) do
      assert_selector "a[href]", count: active.size
      assert_selector "a[aria-disabled='true']:not([href])", count: inactive.size
      inactive.each { |key| assert_selector "a[aria-disabled='true']:not([href])", text: tn(key) }
    end
    active.each do |key, path|
      within(nav) { click_link tn(key) }

      assert_current_path path
      within(nav) { assert_selector "a[aria-current='page'][href='#{path}']", text: tn(key) }
      assert_selector "main#main", text: /\S/
    end
    home = page.current_path
    # The logo may lead back to the very page on screen (an account without active destination): the path alone would
    # match before the visit ends, and the next step would act on the document about to be replaced. The mark on the
    # old body is gone only once the new one is drawn.
    page.execute_script("document.body.dataset.leaving = 'true'")
    find("header a", match: :first).click
    assert_no_selector "body[data-leaving]"
    assert_current_path active.fetch(:home, home)
  end

  # The account menu of the header: « Mon profil » opens the profile, in the shell of the role, and the entry is then
  # marked current (ADR-0055, UDR-0041); « Se déconnecter » ends the session.
  def assert_signs_out
    open_account_menu
    assert_selector "#account-menu a[role=menuitem]:not([aria-current])", text: tn(:profile)
    find("#account-menu a[role=menuitem][href='#{profile_path}']", text: tn(:profile)).click

    assert_current_path profile_path
    assert_selector "aside nav"
    assert_selector "h1", text: I18n.t("identity.profiles.show.title")
    open_account_menu
    assert_selector "#account-menu a[role=menuitem][aria-current='page'][href='#{profile_path}']", text: tn(:profile)
    # Found from the page, never from a kept scope: the sign-out replaces the document (new session, ADR-0049), and a
    # scope kept on the old menu would go stale under a loaded run.
    find("#account-menu [role=menuitem]", text: tn(:sign_out)).click

    assert_current_path root_path
    visit student_home_path
    assert_current_path new_session_path
  end

  # Under a loaded run, the page may still be swapped (Turbo visit, then the reload of ADR-0049) after the first click:
  # the menu opened on the old document vanishes with it. The toggle is clicked again, on the document now shown.
  def open_account_menu
    3.times do
      find("button[aria-controls='account-menu']").click
      return if page.has_selector?("#account-menu", wait: 3)
    end
    assert_selector "#account-menu"
  end
end
