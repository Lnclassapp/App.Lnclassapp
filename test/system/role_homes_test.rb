require "application_system_test_case"

# TR-04, TR-05, TR-09, TR-10 (chantier queries-constantes-orm-disparues, plan Lot E): for every role, a real sign-in, the home
# without error, then every destination of the shell opened by its real link, and the real « Se déconnecter ». A
# destination whose route is not drawn in V1 renders as an inactive entry (NavigationHelper): it is checked as inactive,
# never followed. The data holds assignments: on an empty base, the old feeds passed green by mistake. Since ADR-0072
# an exercise is the only assignable kind: two exercises of the sheet are assigned.
# AN-22 (chantier annonces, UDR-0071 §3.1): « Annonces » closes the navigation of the teacher and of the direction, and the
# secondary list of the team; the student has none.
# UDR-0080 §3.1, §3.2 (app-android), UDR-0081 §3.1, §3.2 (Lnclass Teacher): the student's and the teacher's header has
# no logo and no account menu; they come back home by « Accueil » and sign out from the account panel opened by the avatar.
class RoleHomesTest < ApplicationSystemTestCase
  setup do
    svt = create_material(name: "SVT", category: "science")
    tle = create_level(name: "Tle", position: 7)
    drena = create_drena(name: "Abidjan 1")
    school = create_school(drena:, name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school:, level: tle, name: "Tle D 1", join_code: "kfm37")
    @teacher = create_teacher(school:, material: svt, classrooms: [ @classroom ], first_name: "Yao")
    @student = create_student(classroom: @classroom, first_name: "Aya")
    @school_admin = create_school_admin(school:, first_name: "Mariam")
    course = create_course(name: "Génétique et évolution", level: tle, material: svt)
    essential = create_essential(course:, name: "La méiose")
    exercise = create_exercise(essential:, title: "Exercice sur la méiose")
    [ exercise, create_exercise(essential:, title: "Bilan de la méiose") ].each do |assignable|
      create_assignment(classroom: @classroom, assignable:, by: @teacher)
    end
    session = create_exercise_session(student: @student, exercise:, status: "completed", score_percent: 80)
    create_badge(student: @student, exercise:, level: "gold", session:)
    create_course(name: "Brouillon de l'équipe", level: tle, material: svt, status: "draft")
    create_import_report(kind: "schools", status: "completed", total_count: 1, imported_count: 1)
  end

  def tn(key) = I18n.t("shared.navigation.#{key}")

  test "AN-22 — the student reaches their home, then every destination of their navigation, « Annonces » not among them" do
    sign_in_as @student

    assert_home student_home_path, greeting: I18n.t("classroom.student_homes.show.greeting", name: "Aya")
    assert_text "KFM37"
    within(MAIN_SIDEBAR_NAV) { assert_no_link tn(:announcements) }
    assert_navigation active: { home: student_home_path, courses: courses_path, classroom: student_classroom_path }
    assert_signs_out_from_panel
  end

  test "AN-22 — the teacher reaches their home, then every destination of their navigation, « Annonces » last" do
    sign_in_as @teacher

    assert_home teacher_home_path, greeting: I18n.t("classroom.teacher_homes.show.greeting", name: "Yao")
    assert_navigation active: { home: teacher_home_path, classrooms: teacher_classrooms_path, courses: courses_path,
                                announcements: announcements_path }
    assert_signs_out_from_panel
  end

  # TR-10 (UDR-0049, amendment of UDR-0006 of 2026-09-28): « Pilotage » is drawn, no team destination is inactive.
  # RE-01 (UDR-0068 §3.2): Imports has left the destinations for the « Configuration » card, opened by
  # test/system/teams/configuration_navigation_test.rb.
  # AN-22 (UDR-0071 §3.1, owner's decision of 2026-10-04): the team's « Annonces » is the last entry of its secondary list,
  # on « Mes annonces »: the second card of the sidebar on a desktop, the « Plus » menu on a phone; current on its page.
  test "AN-22 — the team member reaches their home, then every destination of their navigation, « Annonces » by its second card and « Plus »" do
    sign_in_as create_team_member(first_name: "Awa")

    assert_home team_home_path, greeting: I18n.t("teams.homes.show.greeting", name: "Awa")
    assert_navigation active: { home: team_home_path, courses: courses_path, schools: schools_path, dashboard: team_dashboard_path }
    within("nav#sidebar_secondary") do
      assert_equal %i[referential imports announcements].map { tn(it) }, all("a").map { it.text.squish }
      click_link tn(:announcements)
    end

    assert_current_path my_announcements_path
    within("nav#sidebar_secondary") { assert_selector "a[aria-current=page][href='#{my_announcements_path}']", text: tn(:announcements) }
    back_home_by_logo(team_home_path)
    with_mobile_viewport do
      find("button#bottom_bar_more").click
      within("#bottom_bar_more_menu[role=menu]") { click_link tn(:announcements) }

      assert_current_path my_announcements_path
      assert_selector "button#bottom_bar_more[aria-current=page]"
      assert_selector "#bottom_bar_more_menu a[aria-current=page][href='#{my_announcements_path}']", visible: :all
    end
    assert_signs_out
  end

  # The school admin's journey (sign-in, « Accueil », a level, a classroom) is the system test of accueil-direction Lot E
  # (test/system/school_admin/direction_home_test.rb); here, its navigation in order, and « Annonces », last, by its real link.
  test "AN-22 — the direction reaches « Annonces », last of its navigation" do
    sign_in_as @school_admin

    assert_home school_admin_classrooms_path
    within(MAIN_SIDEBAR_NAV) do
      assert_equal %i[home teachers school announcements].map { tn(it) }, all("a[href]").map(&:text)
      click_link tn(:announcements)
    end

    assert_current_path announcements_path
    within(MAIN_SIDEBAR_NAV) { assert_selector "a[aria-current='page'][href='#{announcements_path}']", text: tn(:announcements) }
  end

  test "on a phone, the student opens every destination from the bottom bar" do
    sign_in_as @student

    with_mobile_viewport do
      assert_navigation active: { home: student_home_path, courses: courses_path, classroom: student_classroom_path },
                        nav: "nav.bottom-0"
    end
  end

  # Chantier tests-instables: back to a home already visited, Turbo first draws its cached copy (a preview), then the
  # page received. On a slow network, the account menu opened on the preview vanished with it.
  # The direction: the student's and the teacher's header have neither logo nor account menu (UDR-0080 §3.1, UDR-0081 §3.1).
  test "back home by the logo on a slow network, the account menu opens on the page received, not on its preview" do
    sign_in_as @school_admin
    assert_home school_admin_classrooms_path
    within("aside nav") { click_link tn(:announcements) }
    assert_current_path announcements_path

    on_a_slow_network do
      back_home_by_logo(school_admin_classrooms_path)
      with_account_menu { assert_selector "#account-menu a[role=menuitem]", text: tn(:profile) }
      sleep SLOW_NETWORK_LATENCY / 1000.0
      assert_selector "#account-menu a[role=menuitem][href='#{profile_path}']", text: tn(:profile)
    end
  end

  private

  # The page received after a preview, under a loaded run.
  VISIT_WAIT = 10

  # The page arrived in the shell, not on an error page (rendered in the bare layout): the sidebar is there.
  def assert_home(path, greeting: nil)
    assert_current_path path
    assert_selector "aside nav"
    assert_selector "h1", text: greeting if greeting
  end

  # The first card of the sidebar: the destinations of the role. The team has a second one, « Configuration » (UDR-0068).
  MAIN_SIDEBAR_NAV = "aside nav:not(#sidebar_secondary)".freeze

  # Each active destination is a real link, clicked from the navigation; the page it opens marks it current. An inactive
  # one has no href and aria-disabled. The logo, from the last page, leads back home.
  def assert_navigation(active: {}, inactive: [], nav: MAIN_SIDEBAR_NAV)
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
    back_home_by_logo(active.fetch(:home, page.current_path))
  end

  # The logo may lead back to the very page on screen (an account without active destination): the path alone would
  # match before the visit ends, and the next step would act on the document about to be replaced. The mark on the
  # old body is gone only once a new one is drawn; but a home already visited is first drawn from Turbo's cache (a
  # preview), then replaced by the page received. The visit is over only once Turbo lifts aria-busy from <html>.
  # The student's header has no logo (UDR-0080 §3.1): « Accueil » of the navigation on screen takes its place.
  def back_home_by_logo(home)
    page.execute_script("document.body.dataset.leaving = 'true'")
    if page.has_selector?("header img[src*='logo']", wait: 0)
      find("header a", match: :first).click
    else
      first(:link, tn(:home), href: home).click
    end
    assert_no_selector "body[data-leaving]"
    assert_no_selector "html[aria-busy]", wait: VISIT_WAIT
    assert_current_path home
  end

  # The account menu of the header: « Mon profil » opens the profile, in the shell of the role, and the entry is then
  # marked current (ADR-0055, UDR-0041); « Se déconnecter » ends the session.
  def assert_signs_out
    with_account_menu { assert_selector "#account-menu a[role=menuitem]:not([aria-current])", text: tn(:profile) }
    find("#account-menu a[role=menuitem][href='#{profile_path}']", text: tn(:profile)).click

    assert_current_path profile_path
    assert_selector "aside nav"
    assert_selector "h1", text: I18n.t("identity.profiles.show.title")
    with_account_menu do
      assert_selector "#account-menu a[role=menuitem][aria-current='page'][href='#{profile_path}']", text: tn(:profile)
    end
    # Found from the page, never from a kept scope: the sign-out replaces the document (new session, ADR-0049), and a
    # scope kept on the old menu would go stale under a loaded run.
    find("#account-menu [role=menuitem]", text: tn(:sign_out)).click

    assert_current_path root_path
    visit student_home_path
    assert_current_path new_session_path
  end

  # UDR-0080 §3.2, UDR-0081 §3.2: the student's and the teacher's « Mon profil » and « Se déconnecter » live in the
  # account panel opened by the avatar.
  def assert_signs_out_from_panel
    with_account_panel { assert_selector "nav a:not([aria-current])", text: tn(:profile) }
    find("dialog#account_panel[open] nav a[href='#{profile_path}']", text: tn(:profile)).click

    assert_current_path profile_path
    assert_selector "aside nav"
    assert_selector "h1", text: I18n.t("identity.profiles.show.title")
    with_account_panel { assert_selector "nav a[aria-current='page'][href='#{profile_path}']", text: tn(:profile) }
    find("dialog#account_panel[open] button", text: tn(:sign_out)).click

    assert_current_path root_path
    visit student_home_path
    assert_current_path new_session_path
  end

  # As with_account_menu: the panel is reopened on the document now shown.
  def with_account_panel(&)
    attempts = 0
    begin
      find("header a[aria-controls=account_panel]").click if page.has_no_selector?("dialog#account_panel[open]", wait: 0)
      within("dialog#account_panel[open]", &)
    rescue Minitest::Assertion, Capybara::ElementNotFound, Selenium::WebDriver::Error::StaleElementReferenceError
      raise if (attempts += 1) >= 3

      retry
    end
  end

  # Under a loaded run, the page may still be swapped (Turbo visit, then the reload of ADR-0049) after the menu opened:
  # the menu vanishes with the old document. The menu is reopened on the document now shown, and the expectations on
  # its content are checked again, three times at most.
  def with_account_menu
    attempts = 0
    begin
      find("button[aria-controls='account-menu']").click if page.has_no_selector?("#account-menu", wait: 0)
      assert_selector "#account-menu"
      yield
    rescue Minitest::Assertion, Capybara::ElementNotFound, Selenium::WebDriver::Error::StaleElementReferenceError
      raise if (attempts += 1) >= 3

      retry
    end
  end
end
