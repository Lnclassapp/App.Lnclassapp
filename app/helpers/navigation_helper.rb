# 🌐 UI · NavigationHelper — shell applicatif unique, paramétré par le rôle
# Rôle : destinations de chaque rôle (bureau = mobile), état actif, compte, sections de l'accueil
# UDR  : 0006, 0052, 0054, 0056, 0068, 0069, 0071, 0074, 0076, 0077
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
  # UDR-0071 §3.1 : « Annonces » en dernier pour l'enseignant et la direction ; l'élève n'en a pas (son carrousel mène à
  # « Toutes les annonces ») ; celle de l'équipe est dans sa liste secondaire.
  DESTINATIONS = {
    student: [ [ :home, :student_home_path, "home" ], [ :courses, :courses_path, "book-open" ],
               [ :classroom, :student_classroom_path, "academic-cap" ] ],
    teacher: [ [ :home, :teacher_home_path, "home" ], [ :classrooms, :teacher_classrooms_path, "user-group" ],
               [ :courses, :courses_path, "book-open" ], [ :announcements, :announcements_path, "megaphone" ] ],
    # UDR-0068 §3.1 : Imports passe dans la liste secondaire (2e carte, menu « Plus »).
    team: [ [ :home, :team_home_path, "home" ], [ :courses, :courses_path, "book-open" ],
            [ :schools, :schools_path, "building-library" ], [ :dashboard, :team_dashboard_path, "chart-bar" ] ],
    # UDR-0056 §3.1, UDR-0074 §3.1 : « Accueil » à l'adresse de l'ancien « Travail des élèves » ; UDR-0071 §3.1 : « Annonces » en dernier.
    school_admin: [ [ :home, :school_admin_classrooms_path, "home" ], [ :teachers, :school_admin_teachers_path, "user-group" ],
                    [ :school, :school_admin_school_path, "building-library" ], [ :announcements, :announcements_path, "megaphone" ] ]
  }.freeze
  # UDR-0068 §3.1 : la configuration de l'équipe, 2e carte de la barre latérale et menu « Plus » de la barre basse.
  # Décision du porteur (chantier annonces, 2026-10-04) : « Annonces » y vient en dernier, sur « Mes annonces » ; la barre
  # basse de l'équipe garde ses 5 cases.
  SECONDARY_DESTINATIONS = {
    team: [ [ :referential, :teams_referential_path, "squares-2x2" ], [ :imports, :teams_imports_path, "arrow-up-tray" ],
            [ :announcements, :my_announcements_path, "megaphone" ] ]
  }.freeze
  # UDR-0069 §3.6 : frames différés posés sous les cartes de la barre latérale, par rôle : [id du frame, route de la source].
  SIDEBAR_FRAMES = { teacher: [ [ "sidebar_referral", :teacher_invite_path ] ] }.freeze
  # ADR-0076 §4.2 : un frame de la barre latérale est permanent. Une visite Turbo garde la carte déjà chargée au lieu de
  # la redemander à chaque page ; une page qui a déjà ses données la rend avec elle, sous les mêmes options.
  SIDEBAR_FRAME_OPTIONS = { target: "_top", class: "mt-4 block", data: { turbo_permanent: true } }.freeze
  ACCOUNT_LINKS = [ [ :profile, :profile_path, "user-circle", nil ],
                    [ :sign_out, :session_path, "arrow-right-start-on-rectangle", :delete ] ].freeze
  # Sections de l'accueil de chaque rôle (squelette) — reprises des fils d'accueil de l'ancienne application.
  # Celles de la direction ne servent plus qu'à la page de démonstration du shell (UDR-0052).
  # Élève : les annonces juste après « À faire » (UDR-0071 §3.1) ; une vue qui ne connaît pas une clé ne rend rien.
  HOME_SECTIONS = {
    # UDR-0076 §3.1 : classe, matières, annonces, à faire ; l'activité récente suit toujours, hors de cette liste.
    student: [ [ :classroom, "academic-cap" ], [ :subjects, "squares-2x2" ], [ :announcements, "megaphone" ],
               [ :todo, "clipboard-document-check" ] ],
    # UDR-0069 §3.1 : « Cours » passe en 2e ; UDR-0068 §3.4 : le Référentiel quitte l'accueil équipe.
    # UDR-0077 §3.1 : classes, cours, annonces, activités (les exercices à suivre).
    teacher: [ [ :classrooms, "user-group" ], [ :courses, "book-open" ], [ :announcements, "megaphone" ], [ :activity, "bolt" ] ],
    team: [ [ :regions, "building-library" ], [ :activity, "bolt" ] ],
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

  # Liste secondaire du rôle (UDR-0068) ; vide pour un rôle qui n'en a pas.
  def secondary_navigation_for(role)
    SECONDARY_DESTINATIONS.fetch(role.to_sym, []).map { |key, route, icon| Destination.new(key:, route:, icon:) }
  end

  # Cases de la barre basse : les destinations, plus « Plus » si le rôle a une liste secondaire.
  def bottom_bar_size(role)
    navigation_for(role).size + (secondary_navigation_for(role).any? ? 1 : 0)
  end

  # « Plus » est actif quand la page ouverte est l'une de ses entrées.
  def more_active?(role)
    secondary_navigation_for(role).any? { nav_active?(it) }
  end

  # Frames différés de la barre latérale du rôle, sauf celui dont la source est la page ouverte (elle porte déjà le bloc).
  def sidebar_frames_for(role)
    SIDEBAR_FRAMES.fetch(role.to_sym, []).filter_map do |id, route|
      next unless respond_to?(route)

      src = public_send(route)
      [ id, src ] unless current_page?(src)
    end
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

  # Retour vers une liste filtrée (UDR-0054 §3.2) : l'URL de provenance si elle est de ce même hôte et que son chemin
  # est exactement `from` (chaîne de requête conservée), sinon `default`. Jamais une adresse d'un autre site.
  def back_href(default, from:)
    referer = URI.parse(request.referer.to_s)
    referer.host == request.host && referer.path == from ? referer.request_uri : default
  rescue URI::InvalidURIError
    default
  end
end
