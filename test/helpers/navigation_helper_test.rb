require "test_helper"

class NavigationHelperTest < ActionView::TestCase
  helper ComponentsHelper

  # Ces routes sont remplacées ici ; les V1 sont dessinées (config/routes), celles des vagues suivantes restent inactives.
  def courses_path = "/courses"
  def student_home_path = "/student"
  def profile_path = "/profile"

  test "every role has its destinations, served to both navigations" do
    NavigationHelper::DESTINATIONS.each_key do |role|
      destinations = navigation_for(role.to_s)

      assert_equal :home, destinations.first.key
      assert_operator destinations.size, :<=, NavigationHelper::NAV_GRIDS.keys.max
      assert nav_grid_class(destinations.size)
    end
    assert_raises(KeyError) { navigation_for(:parent) }
  end

  test "nav_path resolves a drawn route and leaves the others inactive" do
    courses = navigation_for(:student)[1]
    dashboard = navigation_for(:team).last

    assert_equal "/courses", nav_path(courses)
    assert_nil nav_path(dashboard)
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
    self.rendered = self.class.content_class.new(nav_link(navigation_for(:team).last, style: :bottom))

    assert_select "a:not([href])[aria-disabled=true]:not([aria-current]).opacity-50.text-2xs",
                  text: /#{I18n.t("shared.navigation.dashboard")}/
    assert_raises(KeyError) { nav_link(navigation_for(:team).last, style: :drawer) }
  end

  test "home_path_for falls back to the root when the home route is missing" do
    assert_equal "/student", home_path_for(:student)
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
    define_singleton_method(:respond_to?) { |name, include_all = false| name != :profile_path && super(name, include_all) }

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
end
