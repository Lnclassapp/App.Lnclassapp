# 🌐 UI · NavigationHelper — shell applicatif unique, paramétré par le rôle
# Rôle : destinations de chaque rôle (bureau = mobile), état actif, compte, sections de l'accueil
# UDR  : 0006, 0052, 0054, 0056, 0068, 0069, 0071, 0074, 0076, 0077, 0080 (§3.2), 0082 (§3.2), 0084 (§3.3), 0098 (§3.1), XXXX (écrans enseignant et élève sans répétition, §3.1 à §3.4)
module NavigationHelper
  Destination = Data.define(:key, :route, :icon)
  # Ce que le shell affiche de la personne connectée. Le contrôleur qui rend `layout "shell"` l'expose par `helper_method :shell_user`.
  # public_id : graine de la couleur stable de l'avatar sans photo (UDR-0084 §3.4). about : éléments du détail, séparés,
  # pour le message prêt de WhatsApp (ShellUserQuery::About, UDR-0128) ; nil donne le message simple.
  ShellUser = Data.define(:name, :role, :detail, :avatar_url, :public_id, :about) do
    def initialize(name:, role:, detail: nil, avatar_url: nil, public_id: nil, about: nil) = super

    # L'accueil salue par le prénom, comme l'ancienne application.
    def first_name = name.split.first
  end

  # Une seule liste par rôle, servie à la barre latérale ET à la barre basse : le mobile voit tout ce que voit le bureau.
  # Les noms de route sont le contrat du Lot 0 de la V1 ; une route pas encore dessinée rend l'entrée inactive.
  # UDR-0071 §3.1 : « Annonces » en dernier pour la direction ; l'élève n'en a pas (son carrousel mène à « Toutes les
  # annonces ») ; celle de l'équipe est dans sa liste secondaire. CA-K1 (mvp-teacher-student) : l'enseignant n'en a plus non
  # plus, aucun écran ne lui propose d'écrire une annonce (la route et le code restent). Élève et enseignant n'ont plus de
  # barre basse (`bottom_bar?`) : leurs destinations sont sur l'accueil et dans « Mon compte » ; la barre latérale (lg+) garde
  # cette liste jusqu'aux versions ordinateur.
  DESTINATIONS = {
    student: [ [ :home, :student_home_path, "home" ], [ :courses, :courses_path, "book-open" ],
               [ :classroom, :student_classroom_path, "academic-cap" ] ],
    teacher: [ [ :home, :teacher_home_path, "home" ], [ :classrooms, :teacher_classrooms_path, "user-group" ],
               [ :courses, :courses_path, "book-open" ] ],
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
  # UDR enseignant §3.4 (lot P0) : le Turbo Frame du panneau « Mon compte » ; dès lg, les écrans de retrait (« Mes matières »,
  # « Mes établissements ») s'y ouvrent à la place du menu, sans quitter la page en dessous.
  ACCOUNT_PANEL_FRAME = "account_panel_screen".freeze
  ACCOUNT_LINKS = [ [ :profile, :profile_path, "user-circle", nil ],
                    [ :sign_out, :session_path, "arrow-right-start-on-rectangle", :delete ] ].freeze
  # UDR-0080 §3.2, UDR-0082 §3.2 : panneau du compte des rôles qui l'ont (les autres gardent le menu déroulant) — la
  # page qui le rend sans JavaScript, puis ses entrées [clé i18n, route, icône, plafond], dans l'ordre. Le plafond (4e élément,
  # facultatif) est { cap: :materials | :schools, full: route de l'écran de retrait } : l'entrée affiche « 2 sur 3 » et, à
  # 3 sur 3, passe en gris et mène à `full`. « Mode sombre » (interrupteur) et « Se déconnecter » ferment toujours la liste,
  # rendus par le panneau lui-même. UDR élève §3.1 : profil, code secret. UDR enseignant §3.4 : profil, code secret,
  # matière, établissement ; « Inviter un collègue » n'y est plus (il est dans la grille de l'accueil).
  ACCOUNT_PANELS = {
    student: { page: :student_menu_path, links: [ [ "shared.navigation.profile", :profile_path, "user-circle" ],
                                                  [ "shared.navigation.account_panel.entries.secret", :edit_profile_pin_path, "key" ] ] },
    # UDR-0098 §3.1 : l'établissement en cours se change dans une rubrique du panneau (dès deux établissements).
    teacher: { page: :teacher_menu_path,
               links: [ [ "shared.navigation.profile", :profile_path, "user-circle" ],
                        [ "shared.navigation.account_panel.entries.secret", :edit_profile_pin_path, "key" ],
                        [ "shared.navigation.account_panel.entries.add_material", :edit_profile_materials_path, "book-open",
                          { cap: :materials, full: :profile_materials_path } ],
                        [ "shared.navigation.account_panel.entries.add_school", :teacher_schools_path, "building-office-2",
                          { cap: :schools, full: :teacher_schools_path } ] ] }
  }.freeze
  # Sections de l'accueil de chaque rôle (squelette) — reprises des fils d'accueil de l'ancienne application.
  # Celles de la direction ne servent plus qu'à la page de démonstration du shell (UDR-0052).
  # Élève : les annonces juste après « À faire » (UDR-0071 §3.1) ; une vue qui ne connaît pas une clé ne rend rien.
  HOME_SECTIONS = {
    # UDR-0076 §3.1 : classe, matières, annonces, à faire ; l'activité récente suit toujours, hors de cette liste.
    student: [ [ :classroom, "academic-cap" ], [ :subjects, "squares-2x2" ], [ :announcements, "megaphone" ],
               [ :todo, "clipboard-document-check" ] ],
    # UDR-0069 §3.1 : « Cours » passe en 2e ; UDR-0068 §3.4 : le Référentiel quitte l'accueil équipe.
    # UDR-0077 §3.1 : classes, cours, annonces, activités (les exercices à suivre).
    # UDR enseignant §3.3 : classes, niveaux, annonces, cette semaine (activity), historique.
    teacher: [ [ :classrooms, "user-group" ], [ :courses, "book-open" ], [ :announcements, "megaphone" ], [ :activity, "bolt" ],
               [ :history, "clock" ] ],
    team: [ [ :regions, "building-library" ], [ :activity, "bolt" ] ],
    school_admin: [ [ :overview, "chart-bar" ], [ :classrooms, "squares-2x2" ], [ :activity, "bolt" ] ]
  }.freeze
  # Filet de couleur en haut de l'en-tête. UDR enseignant §3.1 : l'enseignant n'en a plus (doublon du bandeau de l'accueil).
  ROLE_ACCENTS = { student: "bg-brand", team: "bg-team", school_admin: "bg-school" }.freeze
  # UDR enseignant §3.1 : la couleur du bandeau, des barres de progression et des segments d'étape, choisie par le rôle à cet
  # unique endroit ; aucune vue n'écrit `bg-teacher` en dur.
  ROLE_FILLS = { student: "bg-brand", teacher: "bg-teacher" }.freeze

  NAV_STYLES = {
    sidebar: { base: "flex min-h-tap items-center gap-3 rounded-ln px-4 text-sm font-medium transition",
               active: "bg-brand-soft text-ink", idle: "text-mute hover:bg-mist hover:text-ink" },
    # UDR enseignant §3.14, CA-G11 : l'entrée active de l'enseignant est bleu clair à texte bleu, jamais jaune.
    sidebar_teacher: { base: "flex min-h-tap items-center gap-3 rounded-ln px-4 text-sm font-medium transition",
                       active: "bg-brand-soft text-brand-strong", idle: "text-mute hover:bg-mist hover:text-ink" },
    bottom: { base: "flex min-h-tap flex-col items-center justify-center gap-1 rounded-ln px-1 py-1.5 text-2xs font-medium transition",
              active: "text-ink", idle: "text-mute hover:text-ink" }
  }.freeze
  NAV_ICON_STYLES = {
    sidebar: { active: "text-brand-strong", idle: "" },
    sidebar_teacher: { active: "text-brand-strong", idle: "" },
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

  # UDR-0084 §3.3, UDR enseignant §3.3 : ni l'élève ni l'enseignant n'ont de barre du bas (accueil et « Mon compte » portent
  # leurs destinations) ; la direction et l'équipe la gardent.
  def bottom_bar?(role)
    !%i[student teacher].include?(role.to_sym)
  end

  # Noms courts des matières de l'enseignant (« Maths », « PC ») : le shell les donne en une phrase (« Maths, PC »), les noms
  # courts viennent de `shared.subjects.short`, sinon le nom entier.
  def teacher_subjects(user)
    user.about&.material.to_s.split(", ").map { I18n.t("shared.subjects.short.#{it.parameterize}", default: it) }
  end

  # UDR enseignant §3.4, §3.14 : « Maths · PC · sigle » (sans sigle, le nom de l'établissement), sous le nom, dans « Mon compte »
  # et dans la barre latérale.
  def teacher_detail(user)
    current = teacher_schools.find(&:current)
    school = current ? (current.sigle.presence || current.name) : user.about&.school
    [ *teacher_subjects(user), school ].compact_blank.join(" · ")
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

  def account_panel?(role)
    ACCOUNT_PANELS.key?(role.to_sym)
  end

  # Adresse de la page du panneau : cible du déclencheur-lien de l'avatar.
  def account_panel_page_path(role)
    public_send(ACCOUNT_PANELS.fetch(role.to_sym)[:page])
  end

  # → [{ label:, href:, icon:, cap:, full_href: }] ; cap et full_href sont nil pour une entrée sans plafond.
  def account_panel_links(role)
    ACCOUNT_PANELS.fetch(role.to_sym)[:links].map do |key, route, icon, limit|
      { label: t(key), href: public_send(route), icon:, cap: limit&.fetch(:cap), full_href: (public_send(limit[:full]) if limit) }
    end
  end

  def home_sections_for(role)
    HOME_SECTIONS.fetch(role.to_sym)
  end

  # nil pour un rôle sans filet (l'enseignant).
  def role_accent(role)
    ROLE_ACCENTS[role.to_sym]
  end

  # UDR enseignant §3.1 : bg-brand (élève) ou bg-teacher (enseignant) ; KeyError pour les autres rôles, qui n'ont pas cet accueil.
  def role_fill_class(role)
    ROLE_FILLS.fetch(role.to_sym)
  end

  # Retour vers une liste filtrée (UDR-0054 §3.2) : l'URL de provenance si elle est de ce même hôte et que son chemin
  # est exactement `from` (chaîne de requête conservée), sinon `default`. Jamais une adresse d'un autre site. Seule une
  # adresse http(s) a une request_uri : `//hôte/chemin` ou `ftp://hôte/chemin` reviennent au défaut, jamais à une 500.
  def back_href(default, from:)
    referer = URI.parse(request.referer.to_s)
    referer.is_a?(URI::HTTP) && referer.host == request.host && referer.path == from ? referer.request_uri : default
  rescue URI::InvalidURIError
    default
  end
end
