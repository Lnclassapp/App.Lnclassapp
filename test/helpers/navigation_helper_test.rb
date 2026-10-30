require "test_helper"

class NavigationHelperTest < ActionView::TestCase
  helper ComponentsHelper

  # Ces routes sont remplacées ici ; les V1 sont dessinées (config/routes), celles des vagues suivantes restent inactives.
  def courses_path = "/courses"
  def student_home_path = "/student"
  def profile_path = "/profile"
  def edit_profile_pin_path = "/profile/pin/edit"

  # A route not drawn yet, simulated: every destination of the shell is drawn since espace-direction-simple.
  def without_route(name)
    define_singleton_method(:respond_to?) { |candidate, include_all = false| candidate != name && super(candidate, include_all) }
  end

  test "every role has its destinations, served to both navigations" do
    NavigationHelper::DESTINATIONS.each_key do |role|
      destinations = navigation_for(role.to_s)

      assert_not_empty destinations
      # UDR-0068 §3.1 : « Plus » prend une case de la barre basse ; 5 cases au plus.
      assert_operator bottom_bar_size(role), :<=, NavigationHelper::NAV_GRIDS.keys.max
      assert nav_grid_class(bottom_bar_size(role))
    end
    assert_raises(KeyError) { navigation_for(:parent) }
  end

  # AN-22 (UDR-0071 §3.1), CA-K1 (mvp-teacher-student) : « Annonces », en dernier, pour la direction ; pour l'équipe, en dernier de
  # sa liste secondaire (décision du porteur), sur « Mes annonces » ; jamais pour l'élève ni, depuis CA-K1, pour l'enseignant.
  test "AN-22 — « Annonces » closes the navigation of the direction and the team's secondary list, never the student's or the teacher's" do
    announcements = navigation_for(:school_admin).last

    assert_equal [ :announcements, "/announcements", "megaphone" ], [ announcements.key, nav_path(announcements), announcements.icon ]
    team = secondary_navigation_for(:team).last

    assert_equal [ :announcements, "/announcements/mine", "megaphone" ], [ team.key, nav_path(team), team.icon ]
    assert_not_includes navigation_for(:team).map(&:key), :announcements
    assert_equal "Annonces", I18n.t("shared.navigation.announcements")
    assert_not_includes navigation_for(:student).map(&:key), :announcements
    assert_equal [ 3, 4, 5, 3 ], %i[teacher school_admin team student].map { bottom_bar_size(it) }
  end

  # CA-K1 : aucune entrée de navigation de l'enseignant ne mène aux annonces ni n'en propose l'écriture (barre latérale,
  # liste secondaire) ; les routes et le code restent.
  test "CA-K1 — nothing in the teacher's navigation reaches the announcements, written or read" do
    assert_equal %i[home classrooms courses], navigation_for(:teacher).map(&:key)
    assert_empty secondary_navigation_for(:teacher)
    assert_empty(navigation_for(:teacher).select { %i[announcements my_announcements].include?(it.key) })
    assert_not(NavigationHelper::DESTINATIONS[:teacher].any? { |_, route, _| route.to_s.include?("announcement") })
  end

  # Toute page d'annonces déclare `content_for :nav_key, "announcements"` : l'entrée est active sur chaque onglet, et le
  # « Plus » de l'équipe avec elle.
  test "AN-22 — « Annonces » is active on every tab of the page, by the key its views declare, « Plus » with it for the team" do
    request.path = "/announcements/moderation"

    assert_not more_active?(:team)

    content_for :nav_key, "announcements"
    referential, *, announcements = secondary_navigation_for(:team)

    assert nav_active?(announcements)
    assert nav_active?(navigation_for(:school_admin).last)
    assert_not nav_active?(referential)
    assert more_active?(:team)
  end

  # RE-01, RE-02 (UDR-0068 §3.1) : le quotidien d'un côté, la configuration de l'autre.
  test "the team has its daily destinations and a secondary list for configuration" do
    assert_equal %i[home courses schools dashboard], navigation_for(:team).map(&:key)
    assert_equal [ [ :referential, "/teams/referential", "squares-2x2" ], [ :imports, teams_imports_path, "arrow-up-tray" ],
                   [ :announcements, "/announcements/mine", "megaphone" ] ],
                 secondary_navigation_for(:team).map { [ it.key, nav_path(it), it.icon ] }
    assert_equal 5, bottom_bar_size(:team)
    assert_equal [ "Référentiel", "Imports", "Annonces" ], secondary_navigation_for(:team).map { I18n.t("shared.navigation.#{it.key}") }
    assert_equal "Configuration", I18n.t("shared.navigation.sidebar.secondary_label.team")
  end

  # UDR-0084 §3.3, UDR enseignant §3.3 (mvp-teacher-student) : ni l'élève ni l'enseignant n'ont de barre du bas ; leurs
  # destinations sont sur l'accueil et dans « Mon compte ». La direction et l'équipe la gardent.
  test "the student and the teacher have no bottom bar, the direction and the team keep it" do
    assert_not bottom_bar?(:student)
    assert_not bottom_bar?("student")
    assert_not bottom_bar?(:teacher)
    assert_not bottom_bar?("teacher")
    assert(%i[team school_admin].all? { bottom_bar?(it) })
    assert_equal %i[home courses classroom], navigation_for(:student).map(&:key)
  end

  test "the other roles have no secondary list and no « Plus »" do
    %i[student teacher school_admin].each do |role|
      assert_empty secondary_navigation_for(role)
      assert_equal navigation_for(role).size, bottom_bar_size(role)
      assert_not more_active?(role)
    end
  end

  test "« Plus » is active on one of its entries, by URL or by the key the view declares" do
    request.path = "/teams/dashboard"

    assert_not more_active?(:team)

    request.path = teams_imports_path

    assert more_active?(:team)

    request.path = "/teams"
    content_for :nav_key, "referential"

    assert more_active?(:team)
  end

  test "nav_path resolves a drawn route and leaves the others inactive" do
    courses = navigation_for(:student)[1]
    dashboard = navigation_for(:team).last
    teachers = navigation_for(:school_admin).find { it.key == :teachers }

    assert_equal "/courses", nav_path(courses)
    assert_equal "/teams/dashboard", nav_path(dashboard)
    assert_equal "/school-admin/teachers", nav_path(teachers)
    without_route(:school_admin_teachers_path)

    assert_nil nav_path(teachers)
  end

  # DS-05 (UDR-0052, amendment of UDR-0006), GD-01 (UDR-0056 §3.1), AD-20 (UDR-0074 §3.1): the direction's destinations
  # are all drawn; its home is « Accueil », at the address of the former « Travail des élèves ». AN-22 (UDR-0071 §3.1):
  # « Annonces » comes last.
  test "AD-20: the direction's navigation is « Accueil », « Enseignants », « Établissement » then « Annonces »" do
    assert_equal [ [ :home, "/school-admin/classrooms", "home" ], [ :teachers, "/school-admin/teachers", "user-group" ],
                   [ :school, "/school-admin/school", "building-library" ], [ :announcements, "/announcements", "megaphone" ] ],
                 navigation_for(:school_admin).map { [ it.key, nav_path(it), it.icon ] }
    assert_equal [ "Accueil", "Enseignants", "Établissement", "Annonces" ],
                 navigation_for(:school_admin).map { I18n.t("shared.navigation.#{it.key}") }
    assert_equal "/school-admin/classrooms", home_path_for(:school_admin)
    assert_not I18n.exists?("shared.navigation.student_work"), "no role keeps « Travail des élèves »"
  end

  test "AD-20: « Accueil » of the direction is active on a level's page and on a classroom's page, by the key they declare" do
    request.path = "/school-admin/levels/3eme"
    content_for :nav_key, "home"

    assert nav_active?(navigation_for(:school_admin).first)
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
    self.rendered = self.class.content_class.new(nav_link(navigation_for(:teacher).find { it.key == :courses }, style: :sidebar))

    assert_select "a[href='/courses'][aria-current=page].bg-brand-soft", text: /#{I18n.t("shared.navigation.courses")}/
    assert_select "a:not([aria-disabled]) span.text-brand-strong svg"
  end

  test "the team reaches the imports screen, marked active on its page" do
    request.path = teams_imports_path
    imports = secondary_navigation_for(:team).find { it.key == :imports }
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

  # CA-8, CA-T6 (UDR-0080 §3.2, UDR-0082 §3.2), puis UDR élève §3.1 et UDR enseignant §3.4 (mvp-teacher-student) : l'élève et
  # l'enseignant ont le panneau du compte, chacun avec sa page et ses entrées dans l'ordre ; le mode sombre et « Se déconnecter »
  # sont fixes, rendus par le panneau lui-même. La direction et l'équipe gardent le menu du compte.
  test "the account panel of the student and of the teacher: its page, then its links in order" do
    assert_equal [ true, true, false, false ], %w[student teacher school_admin team].map { account_panel?(it) }
    assert_equal [ "/students/menu", "/teachers/menu" ], %i[student teacher].map { account_panel_page_path(it) }
    assert_equal [ { label: I18n.t("shared.navigation.profile"), href: "/profile", icon: "user-circle" },
                   { label: I18n.t("shared.navigation.account_panel.entries.secret"), href: "/profile/pin/edit", icon: "key" } ],
                 account_panel_links(:student).map { it.slice(:label, :href, :icon) }
    assert_equal [ [ "Mon profil", "/profile", "user-circle", nil, nil ],
                   [ "Modifier mon code secret", "/profile/pin/edit", "key", nil, nil ],
                   [ "Ajouter une matière", "/profile/materials/edit", "book-open", "/profile/materials", :materials ],
                   [ "Ajouter un établissement", "/teachers/schools", "building-office-2", "/teachers/schools", :schools ] ],
                 account_panel_links(:teacher).map { it.values_at(:label, :href, :icon, :full_href, :cap) }
  end

  # UDR enseignant §3.4 : « Inviter un collègue » n'est plus dans le menu (il est dans la grille de l'accueil).
  test "the teacher's account panel no longer invites a colleague, and the student's no longer lists courses" do
    assert_not(account_panel_links(:teacher).any? { it[:href] == "/teachers/invite" })
    assert_not I18n.exists?("shared.navigation.account_panel.invite")
    assert_not(account_panel_links(:student).any? { it[:href] == "/courses" })
  end

  # RE-05, RE-11 (UDR-0068 §3.4, UDR-0069 §3.1).
  # UDR enseignant §3.3 : classes, niveaux, annonces, cette semaine (activity), puis l'historique.
  test "the teacher's home reads classrooms, courses, announcements, activities then history; the team's has no referential" do
    assert_equal %i[classrooms courses announcements activity history], home_sections_for(:teacher).map(&:first)
    assert_equal %i[regions activity], home_sections_for(:team).map(&:first)
  end

  # UDR-0076 §3.1 : l'accueil de l'élève se lit classe, matières, annonces, à faire ; l'activité récente suit toujours.
  test "the student's home reads classroom, subjects, announcements then todo, without a courses card" do
    assert_equal %i[classroom subjects announcements todo], home_sections_for(:student).map(&:first)
  end

  # UDR enseignant §3.1 : le filet de couleur du rôle disparaît pour l'enseignant (le bandeau de l'accueil le remplace).
  test "home sections exist for every role; the accent exists for every role but the teacher" do
    NavigationHelper::DESTINATIONS.each_key do |role|
      assert_not_empty home_sections_for(role.to_s)
    end
    %i[student team school_admin].each { assert_match(/\Abg-/, role_accent(it.to_s)) }
    assert_nil role_accent(:teacher)
    assert_nil role_accent("teacher")
  end

  # UDR enseignant §3.1 : la couleur du bandeau, des barres et des segments se choisit par le rôle, à un seul endroit.
  test "role_fill_class gives the student's blue and the teacher's yellow, and nothing for the other roles" do
    assert_equal "bg-brand", role_fill_class(:student)
    assert_equal "bg-brand", role_fill_class("student")
    assert_equal "bg-teacher", role_fill_class(:teacher)
    assert_equal "bg-teacher", role_fill_class("teacher")
    assert_raises(KeyError) { role_fill_class(:team) }
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
      "mailto:x@y.ci" => "a referer without host",
      "//test.host/teams/schools?search=x" => "a referer without scheme",
      "ftp://test.host/teams/schools" => "a referer of another scheme"
    }.each do |referer, reason|
      request.env["HTTP_REFERER"] = referer

      assert_equal "/teams/schools", back_href("/teams/schools", from: "/teams/schools"), reason
    end
  end

  # carte-profil-eleve (UDR-0132 §3.1, amendée) : « classe · sigle », le nom faute de sigle, nil sans classe active.
  test "student_detail: the classroom and the school's sigle, else its name; nil without a classroom" do
    about = ->(**parts) { NavigationHelper::ShellUser.new(name: "Awa Koné", role: :student, about: Queries::Identity::ShellUserQuery::About.new(gender: "female", **parts)) }

    assert_equal "3ème B · LMC", student_detail(about.(classroom: "3ème B", school: "Lycée Moderne de Cocody", sigle: "LMC"))
    assert_equal "3ème B · Lycée Moderne de Cocody", student_detail(about.(classroom: "3ème B", school: "Lycée Moderne de Cocody", sigle: ""))
    assert_nil student_detail(about.())
    assert_nil student_detail(NavigationHelper::ShellUser.new(name: "Awa Koné", role: :student))
  end
end
