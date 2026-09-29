require "test_helper"

class NavigationHelperTest < ActionView::TestCase
  helper ComponentsHelper

  # Ces routes sont remplacées ici ; les V1 sont dessinées (config/routes), celles des vagues suivantes restent inactives.
  def courses_path = "/courses"
  def student_home_path = "/student"
  def profile_path = "/profile"

  # A route not drawn yet, simulated: every destination of the shell is drawn since espace-direction-simple.
  def without_route(name)
    define_singleton_method(:respond_to?) { |candidate, include_all = false| candidate != name && super(candidate, include_all) }
  end

  test "every role has its destinations, served to both navigations" do
    NavigationHelper::DESTINATIONS.each_key do |role|
      destinations = navigation_for(role.to_s)

      assert_not_empty destinations
      assert_operator destinations.size, :<=, NavigationHelper::NAV_GRIDS.keys.max
      assert nav_grid_class(destinations.size)
    end
    assert_raises(KeyError) { navigation_for(:parent) }
  end

  test "nav_path resolves a drawn route and leaves the others inactive" do
    courses = navigation_for(:student)[1]
    dashboard = navigation_for(:team).last
    teachers = navigation_for(:school_admin).last

    assert_equal "/courses", nav_path(courses)
    assert_equal "/teams/dashboard", nav_path(dashboard)
    assert_equal "/school-admin/teachers", nav_path(teachers)
    without_route(:school_admin_teachers_path)

    assert_nil nav_path(teachers)
  end

  # DS-05 (UDR-0052, amendment of UDR-0006): the direction has exactly two destinations, both drawn, and no home
  # of its own: « Travail des élèves » is its home.
  test "the direction's navigation is « Travail des élèves » then « Enseignants »" do
    assert_equal [ [ :student_work, "/school-admin/classrooms", "chart-bar" ], [ :teachers, "/school-admin/teachers", "user-group" ] ],
                 navigation_for(:school_admin).map { [ it.key, nav_path(it), it.icon ] }
    assert_equal [ "Travail des élèves", "Enseignants" ],
                 navigation_for(:school_admin).map { I18n.t("shared.navigation.#{it.key}") }
    assert_equal "/school-admin/classrooms", home_path_for(:school_admin)
  end

  test "a destination is active by its URL or by the key the view declares" do
    request.path = "/courses"
    home, courses, classroom = navigation_for(:student)

    assert nav_active?(courses)
    assert_not nav_active?(home)
    assert_not nav_active?(classroom)

    content_for :nav_key, "classroom"

    assert nav_active?(classroom)
  end

  test "nav_link renders an active sidebar link with a solid icon" do
    request.path = "/courses"
    self.rendered = self.class.content_class.new(nav_link(navigation_for(:teacher).last, style: :sidebar))

    assert_select "a[href='/courses'][aria-current=page].bg-brand-soft", text: /#{I18n.t("shared.navigation.courses")}/
    assert_select "a:not([aria-disabled]) span.text-brand-strong svg"
  end

  test "the team reaches the imports screen, marked active on its page" do
    request.path = teams_imports_path
    imports = navigation_for(:team).find { it.key == :imports }
    self.rendered = self.class.content_class.new(nav_link(imports, style: :sidebar))

    assert_select "a[href='#{teams_imports_path}'][aria-current=page]", text: /Imports/
  end

  test "nav_link renders an idle, inactive bottom link when the route is missing" do
    # Every destination is drawn since the direction's (espace-direction-simple): a missing route is simulated.
    without_route(:school_admin_teachers_path)
    teachers = navigation_for(:school_admin).find { it.key == :teachers }
    self.rendered = self.class.content_class.new(nav_link(teachers, style: :bottom))

    assert_select "a:not([href])[aria-disabled=true]:not([aria-current]).opacity-50.text-2xs",
                  text: /#{I18n.t("shared.navigation.teachers")}/
    assert_raises(KeyError) { nav_link(teachers, style: :drawer) }
  end

  test "home_path_for falls back to the root when the home route is missing" do
    assert_equal "/student", home_path_for(:student)
    without_route(:school_admin_classrooms_path)

    assert_equal root_path, home_path_for(:school_admin)
  end

  test "account_links point to drawn routes and mark sign out as dangerous" do
    profile, sign_out = account_links

    assert_equal({ label: I18n.t("shared.navigation.profile"), href: "/profile", icon: "user-circle", method: nil, tone: :default }, profile)
    assert_equal "/session", sign_out[:href]
    assert_equal :delete, sign_out[:method]
    assert_equal :danger, sign_out[:tone]
  end

  # « Mon profil » is drawn since the profil-utilisateur chantier; an account route not drawn yet keeps its entry inactive.
  test "an account link whose route is not drawn has no href" do
    without_route(:profile_path)

    assert_nil account_links.first[:href]
  end

  test "home sections and accents exist for every role" do
    NavigationHelper::DESTINATIONS.each_key do |role|
      assert_not_empty home_sections_for(role.to_s)
      assert_match(/\Abg-/, role_accent(role.to_s))
    end
  end

  test "the shell user greets by first name and has optional details" do
    user = NavigationHelper::ShellUser.new(name: "Mariam Traoré", role: :teacher)

    assert_equal "Mariam", user.first_name
    assert_nil user.detail
    assert_nil user.avatar_url
  end

  # UDR-0054 §3.2 — the back link returns to the filtered list the person came from, and nowhere else.
  test "back_href returns to the list the person came from, query string kept" do
    request.env["HTTP_REFERER"] = "http://test.host/teams/schools?search=lyc%C3%A9e&status=active"

    assert_equal "/teams/schools?search=lyc%C3%A9e&status=active", back_href("/teams/schools", from: "/teams/schools")
  end

  test "back_href falls back to its default without a referer, from another page or from another host" do
    assert_equal "/teams/schools", back_href("/teams/schools", from: "/teams/schools")

    {
      "http://test.host/teams/schools/abc" => "another page",
      "http://evil.example/teams/schools?search=x" => "another host",
      "http://test.host/teams" => "a shorter path",
      "not a uri at all ::" => "a malformed referer",
      "mailto:x@y.ci" => "a referer without host"
    }.each do |referer, reason|
      request.env["HTTP_REFERER"] = referer

      assert_equal "/teams/schools", back_href("/teams/schools", from: "/teams/schools"), reason
    end
  end
end
