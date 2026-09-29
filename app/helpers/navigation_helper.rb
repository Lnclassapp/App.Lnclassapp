# 🌐 UI · NavigationHelper — shell applicatif unique, paramétré par le rôle
# Rôle : destinations de chaque rôle (bureau = mobile), état actif, compte, sections de l'accueil
# UDR  : 0006, 0052
module NavigationHelper
  Destination = Data.define(:key, :route, :icon)
  # Ce que le shell affiche de la personne connectée. Le contrôleur qui rend `layout "shell"` l'expose par `helper_method :shell_user`.
  ShellUser = Data.define(:name, :role, :detail, :avatar_url) do
    def initialize(name:, role:, detail: nil, avatar_url: nil) = super

    # L'accueil salue par le prénom, comme l'ancienne application.
    def first_name = name.split.first
  end

  # Une seule liste par rôle, servie à la barre latérale ET à la barre basse : le mobile voit tout ce que voit le bureau.
  # Les noms de route sont le contrat du Lot 0 de la V1 ; une route pas encore dessinée rend l'entrée inactive.
  DESTINATIONS = {
    student: [ [ :home, :student_home_path, "home" ], [ :courses, :courses_path, "book-open" ],
               [ :classroom, :student_classroom_path, "academic-cap" ] ],
    teacher: [ [ :home, :teacher_home_path, "home" ], [ :classrooms, :teacher_classrooms_path, "user-group" ],
               [ :courses, :courses_path, "book-open" ] ],
    team: [ [ :home, :team_home_path, "home" ], [ :courses, :courses_path, "book-open" ],
            [ :schools, :schools_path, "building-library" ], [ :imports, :teams_imports_path, "arrow-up-tray" ],
            [ :dashboard, :team_dashboard_path, "chart-bar" ] ],
    # UDR-0052 : deux destinations, sans accueil ; « Travail des élèves » est l'accueil de la direction.
    school_admin: [ [ :student_work, :school_admin_classrooms_path, "chart-bar" ], [ :teachers, :school_admin_teachers_path, "user-group" ] ]
  }.freeze
  ACCOUNT_LINKS = [ [ :profile, :profile_path, "user-circle", nil ],
                    [ :sign_out, :session_path, "arrow-right-start-on-rectangle", :delete ] ].freeze
  # Sections de l'accueil de chaque rôle (squelette) — reprises des fils d'accueil de l'ancienne application.
  # Celles de la direction ne servent plus qu'à la page de démonstration du shell (UDR-0052).
  HOME_SECTIONS = {
    student: [ [ :todo, "clipboard-document-check" ], [ :classroom, "academic-cap" ], [ :courses, "book-open" ] ],
    teacher: [ [ :classrooms, "user-group" ], [ :activity, "bolt" ], [ :courses, "book-open" ] ],
    team: [ [ :regions, "building-library" ], [ :levels, "squares-2x2" ], [ :activity, "bolt" ] ],
    school_admin: [ [ :overview, "chart-bar" ], [ :classrooms, "squares-2x2" ], [ :activity, "bolt" ] ]
  }.freeze
  ROLE_ACCENTS = { student: "bg-brand", teacher: "bg-teacher", team: "bg-team", school_admin: "bg-school" }.freeze

  NAV_STYLES = {
    sidebar: { base: "flex min-h-tap items-center gap-3 rounded-ln px-4 text-sm font-medium transition",
               active: "bg-brand-soft text-ink", idle: "text-mute hover:bg-mist hover:text-ink" },
    bottom: { base: "flex min-h-tap flex-col items-center justify-center gap-1 rounded-ln px-1 py-1.5 text-2xs font-medium transition",
              active: "text-ink", idle: "text-mute hover:text-ink" }
  }.freeze
  NAV_ICON_STYLES = {
    sidebar: { active: "text-brand-strong", idle: "" },
    bottom: { active: "rounded-full bg-brand-soft px-4 py-0.5 text-brand-strong", idle: "px-4 py-0.5" }
  }.freeze
  NAV_GRIDS = { 1 => "grid-cols-1", 2 => "grid-cols-2", 3 => "grid-cols-3", 4 => "grid-cols-4", 5 => "grid-cols-5" }.freeze

  def navigation_for(role)
    DESTINATIONS.fetch(role.to_sym).map { |key, route, icon| Destination.new(key:, route:, icon:) }
  end

  def nav_path(destination)
    respond_to?(destination.route) ? public_send(destination.route) : nil
  end

  # Actif si la vue l'a déclaré (`content_for :nav_key, "courses"`, utile sous une page imbriquée) ou si l'URL correspond.
  def nav_active?(destination, path = nav_path(destination))
    content_for(:nav_key) == destination.key.to_s || (!path.nil? && current_page?(path))
  end

  def nav_link(destination, style:)
    path = nav_path(destination)
    active = nav_active?(destination, path)
    styles = NAV_STYLES.fetch(style)
    render "shared/navigation/link", path:, active:, destination:,
           classes: class_names(styles[:base], active ? styles[:active] : styles[:idle], { "opacity-50" => path.nil? }),
           icon_classes: NAV_ICON_STYLES.fetch(style)[active ? :active : :idle]
  end

  def nav_grid_class(count)
    NAV_GRIDS.fetch(count)
  end

  def home_path_for(role)
    nav_path(navigation_for(role).first) || root_path
  end

  def account_links
    ACCOUNT_LINKS.map do |key, route, icon, method|
      { label: t("shared.navigation.#{key}"), href: (public_send(route) if respond_to?(route)), icon:, method:,
        tone: key == :sign_out ? :danger : :default }
    end
  end

  def home_sections_for(role)
    HOME_SECTIONS.fetch(role.to_sym)
  end

  def role_accent(role)
    ROLE_ACCENTS.fetch(role.to_sym)
  end
end
