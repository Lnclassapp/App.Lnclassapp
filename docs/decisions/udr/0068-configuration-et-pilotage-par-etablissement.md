# UDR-0068 : Espace équipe — carte « Configuration » et menu « Plus », page Référentiel, recherche de DRENA et pilotage par établissement

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-03 |
| **Chantier** | [`docs/chantiers/reorganisation-equipe-enseignant`](../../chantiers/reorganisation-equipe-enseignant/prd.md) — critères RE-01 à RE-10 |
| **ADR lié** | [ADR-0062](../adr/0062-indicateurs-de-pilotage-lus-en-direct.md) (amendé : « Par établissement ») · [ADR-0067](../adr/0067-budgets-de-temps-serveur-des-ecrans.md) (budget du pilotage) · amende [UDR-0006](0006-shell-applicatif-par-role.md), [UDR-0018](0018-accueil-equipe.md), [UDR-0049](0049-page-pilotage-de-l-equipe.md) · composants [UDR-0005](0005-design-system-fondateur.md), [UDR-0042](0042-actions-de-ligne-dans-un-menu.md) |
| **Remplacé par** | — |

---

## 1. Contexte

La barre latérale de l'équipe mêle le quotidien (Accueil, Cours, Établissements, Pilotage) et l'outillage ponctuel (Imports), et l'accueil porte le Référentiel, qui ne sert qu'à la configuration. Sur le pilotage, le tableau « Par DRENA » ne mène nulle part et aucun écran ne donne les chiffres d'un établissement. Le porteur veut (memo, G7 à G10) : une 2e carte pour la configuration, un menu « Plus » sur téléphone, une recherche de DRENA en tête du tableau, et une DRENA cliquable qui liste les chiffres de ses établissements.

## 2. Décision

1. **Deux listes de navigation pour l'équipe** : les destinations (Accueil, Cours, Établissements, Pilotage) et la configuration (Référentiel, Imports). Ce sont des **données** de `NavigationHelper`, pas des partials par rôle (UDR-0006 §2.1 tient toujours).
2. **Barre latérale** : la configuration est une 2e carte, titrée « Configuration », sous la carte des destinations.
3. **Barre du bas** : les destinations, puis une 5e case « Plus » qui ouvre, **vers le haut**, un menu des entrées de configuration. C'est la seule entrée cachée de l'application, réservée au rôle qui a une 2e liste ; la règle « pas de tiroir » de l'UDR-0006 est amendée pour ce seul cas, la barre restant à 5 cases au plus.
4. **Le Référentiel a sa page** (`/teams/referential`) : tuiles et structure scolaire, inchangées. L'accueil équipe le perd.
5. **Chercher une DRENA filtre les lignes dans le navigateur** : une DRENA n'est pas un compte, la liste tient en une page (41 DRENA), et sans JavaScript toutes les lignes restent visibles (le champ n'apparaît qu'avec JavaScript).
6. **Le nom d'une DRENA est un lien vers le pilotage filtré sur elle** : on réutilise le filtre `drena` existant, la période est gardée, l'URL se partage. Sous filtre, « Par DRENA » (qui n'aurait qu'une ligne) laisse place à **« Par établissement »**.
7. **« Par établissement » est paginé côté serveur** (25 par page) et **cherché côté serveur** (nom d'établissement, toutes les pages) : une grosse DRENA dépasse plusieurs centaines d'établissements, un filtre dans le navigateur ne verrait que la page affichée.
8. **Les chiffres d'un établissement ont les définitions de la ligne DRENA** (ADR-0062) : la somme des établissements listés égale la ligne de la DRENA. Pour que ce soit vrai, la liste contient les établissements **actifs**, plus tout établissement non actif qui a encore une classe, un enseignant ou un élève compté (marqué « Inactif »).

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Navigation — `NavigationHelper`

- `DESTINATIONS[:team]` devient `[ [ :home, :team_home_path, "home" ], [ :courses, :courses_path, "book-open" ], [ :schools, :schools_path, "building-library" ], [ :dashboard, :team_dashboard_path, "chart-bar" ] ]` (Imports en sort).
- Nouvelle constante `SECONDARY_DESTINATIONS = { team: [ [ :referential, :teams_referential_path, "squares-2x2" ], [ :imports, :teams_imports_path, "arrow-up-tray" ] ] }.freeze` et méthode `secondary_navigation_for(role)` → `Destination` (même forme que `navigation_for`), `[]` pour un rôle absent.
- `nav_active?` vaut aussi pour une entrée secondaire (clé déclarée par `content_for :nav_key` ou URL courante). Nouvelle méthode `more_active?(role)` : vrai si une entrée secondaire est active.
- Les cases de la barre du bas = `navigation_for(role).size + (secondary_navigation_for(role).any? ? 1 : 0)`, jamais plus de 5 (`NAV_GRIDS`).
- `HOME_SECTIONS[:team]` devient `[ [ :regions, "building-library" ], [ :activity, "bolt" ] ]`.
- Locales `config/locales/shared/navigation.fr.yml` : `shared.navigation.referential: "Référentiel"` ; `shared.navigation.sidebar.secondary_label.team: "Configuration"` ; `shared.navigation.bottom_bar.more: "Plus"` ; `shared.navigation.bottom_bar.more_label: "Plus de destinations : %{entries}"` (entrées jointes par « , »).

### 3.2 Barre latérale — `shared/navigation/_sidebar`

- Ordre : carte de profil, `nav` des destinations (inchangée), puis **si** `secondary_navigation_for(user.role).any?` :
  `nav#sidebar_secondary` `aria-labelledby="sidebar_secondary_title"`, classes `mt-4 rounded-card border border-line bg-white p-2 shadow-card` ; dedans `p#sidebar_secondary_title` (`px-4 pt-2 pb-1 text-xs font-semibold tracking-wider text-mute uppercase`) « Configuration », puis `ul.space-y-1` d'un `li` par entrée, `nav_link destination, style: :sidebar`.
- Après les cartes, l'emplacement de la carte de l'enseignant (UDR-0069 §3.6). Rien d'autre.

### 3.3 Barre du bas — `shared/navigation/_bottom_bar` et `_more_menu`

- La grille prend `nav_grid_class(cases)` (§3.1). Les destinations, puis, si le rôle a une liste secondaire, un `li` qui rend `shared/navigation/_more_menu`.
- `_more_menu` (sous le contrôleur Stimulus `dropdown`, comme `components/_dropdown`) :
  - `div.relative` `data-controller="dropdown"` `data-action="keydown->dropdown#keydown click@window->dropdown#outside turbo:before-cache@document->dropdown#close"` ;
  - `button#bottom_bar_more` `type="button"` `aria-haspopup="menu"` `aria-expanded="false"` `aria-controls="bottom_bar_more_menu"` `aria-label` = `more_label` (« Plus de destinations : Référentiel, Imports »), `data-dropdown-target="button"`, `data-action="dropdown#toggle"`, classes de `NAV_STYLES[:bottom]` (base + `active` si `more_active?`, sinon `idle`), `w-full` ; contenu : `ui_icon "ellipsis-horizontal"` (style d'icône `NAV_ICON_STYLES[:bottom]`, plein si actif) puis `span` « Plus » ; `aria-current="page"` si `more_active?` ;
  - `div#bottom_bar_more_menu` `role="menu"` `aria-label` « Configuration » `hidden` `data-dropdown-target="menu"`, classes `absolute right-0 bottom-full z-50 mb-2 w-56 rounded-ln border border-line bg-white p-1.5 shadow-pop animate-fade-in` ; un `ui_dropdown_item(t("shared.navigation.#{key}"), href: nav_path(destination), icon:)` par entrée (l'entrée de la page ouverte reçoit `aria-current="page"` par `ui_dropdown_item`).
- Clavier et fermeture : ceux du contrôleur `dropdown` (flèches, Échap, clic extérieur, avant cache Turbo). Aucun JavaScript nouveau.

### 3.4 Page Référentiel — `GET /teams/referential`

- Route (`config/routes/teams.rb`) : `get "teams/referential", to: "teams/referentials#show", as: :teams_referential`.
- `Teams::ReferentialsController < Teams::BaseController`, `show` : `@home = Queries::Catalog::TeamHomeQuery.new.call`. Garde : celle de `BaseController` (équipe seule, 403 sinon).
- Vue `teams/referentials/show.html.erb` : `page_title` « Référentiel » ; `content_for :nav_key, "referential"` ; `ui_page_header title: « Référentiel », subtitle: « Ce que l'équipe crée avant tout établissement, tout cours et toute classe »` ; puis `render "teams/referentials/summary", home: @home`.
- `teams/referentials/_summary` reprend **à l'identique** le contenu de `teams/homes/_referential` (grille de 5 tuiles liées, « Gérer », puis « Structure scolaire » et ses niveaux), avec deux différences : la carte des tuiles est `ui_card id: "team_referential"` **sans titre** (l'en-tête de page le porte) ; « Structure scolaire » devient sa propre `ui_card id: "team_referential_structure"`, titre « Structure scolaire », icône `squares-2x2`, à `mt-5`. Les identifiants `level_<slug>` sont gardés.
- Locales : les clés `teams.homes.referential.*` passent sous `teams.referentials.summary.*` (`config/locales/teams/referentials.fr.yml`, avec `teams.referentials.show.page_title|title|subtitle`). `teams/homes/_referential` et ses clés sont supprimés.
- Accueil équipe (`teams/homes/show`) : la branche `:levels` disparaît avec `HOME_SECTIONS` ; le raccourci « Importer » reste.
- **Retour des écrans du référentiel** (constat d'intégration) : le lien de retour des écrans DRENA, niveaux, séries, matières et barème des classes mène à `teams_referential_path`, libellé « Référentiel » (il menait à l'accueil, « Accueil »). Le sous-titre de l'accueil équipe devient « Les établissements, l'activité et le contenu de la plateforme. ».

### 3.5 Pilotage — recherche de DRENA (`teams/dashboards/_drenas`)

- La partial reçoit `period:` en plus.
- En tête du corps de la carte (avant le tableau, si `rows.any?`) : `div#drena_filter` `hidden` `class="mb-4 max-w-sm"` `data-table-filter-target="field"` qui contient `label for="drena_filter_input"` (`mb-1.5 block text-sm font-medium text-ink`) « Chercher une DRENA » et `input#drena_filter_input` `type="search"` `autocomplete="off"` (classes `ComponentsHelper::FIELD_INPUT` + `FIELD_STATES[:valid]`) `data-table-filter-target="input"` `data-action="input->table-filter#filter"`.
- La carte entière porte `data-controller="table-filter"` ; chaque `tr#drena_row_<public_id>` porte `data-table-filter-target="row"` et `data-filter-text` = nom de la DRENA en minuscules et sans accents (`I18n.transliterate(name).downcase`).
- Sous le tableau : `p#drena_filter_empty` `hidden` `class="py-4 text-sm text-mute"` « Aucune DRENA ne correspond. » (`data-table-filter-target="empty"`), et `p.sr-only` `aria-live="polite"` `data-table-filter-target="status"`.
- Contrôleur Stimulus `table-filter` (`app/javascript/controllers/table_filter_controller.js`, < 1 Ko gzip) : `connect` retire `hidden` du champ ; `filter` normalise la saisie (`normalize("NFD")`, retire les diacritiques, minuscules, espaces repliés), masque (`hidden`) chaque ligne dont `data-filter-text` ne contient pas la saisie, montre `empty` si aucune ligne ne reste, et écrit dans `status` « N DRENA affichées » (`aria-live`). Saisie vide : tout réapparaît.
- Chaque nom devient un lien : dans `th scope="row"`, `link_to team_dashboard_path(period: period.key, drena: row.public_id), class: "font-medium text-brand-strong underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-brand"` dont le texte est le nom, suivi de `span.sr-only` « , voir ses établissements ». Navigation Turbo de la page entière.

### 3.6 Pilotage — « Par établissement » (`teams/dashboards/_schools`)

- `show.html.erb` : si `@dashboard.drena`, rendre `_schools` (`page: @schools, period: @period, drena: @dashboard.drena, search: @school_search`) **à la place de** `_drenas` ; sinon `_drenas`. Rien d'autre ne bouge.
- Contrôleur : sous filtre DRENA seulement, `@school_search = text_param(:school_q)` et `@schools = Queries::School::DrenaSchoolsQuery.new.call(drena_public_id: text_param(:drena), period: @period, search: @school_search, page: text_param(:school_page))`. `school_q` et `school_page` suivent la règle des paramètres invalides de l'UDR-0049 (amendement du 2026-09-28) : texte sans octet nul, sinon absent ; une page invalide vaut 1, une page trop grande la dernière.
- `ui_card#team_dashboard_schools`, titre « Par établissement », sous-titre « <DRENA> · triés par nombre d'élèves », icône `building-library`.
- Formulaire GET `team_dashboard_path`, `role="search"`, `aria-label` « Chercher un établissement de la DRENA », `class="mb-4 flex flex-wrap items-end gap-3"` : `hidden_field_tag :period`, `hidden_field_tag :drena`, `div.min-w-0.flex-1` avec `label for="school_q"` « Chercher un établissement » et `search_field_tag :school_q, search` (classes de champ), `ui_button` « Chercher » (`icon: "magnifying-glass"`, `type: :submit`, `variant: :secondary`) ; si `search` présent, `ui_button` « Effacer » (`variant: :ghost`) vers la même page sans `school_q`.
- Tableau : même gabarit que `_drenas` (`div.relative.-mx-2.overflow-x-auto` → `table.w-full.min-w-2xl.text-left.text-sm`, `caption.sr-only` « Établissements de <DRENA> sur <période> », `thead` `border-b border-line text-xs text-mute`). Colonnes : Établissement, Classes, Enseignants, Élèves, Élèves actifs (infobulle « Élèves actifs » de l'UDR-0054, reprise). Ligne `tr#school_row_<public_id>` : `th scope="row"` avec le nom (`font-medium text-ink`, **sans lien**) et, si l'établissement n'est pas actif, `ui_badge "Inactif", size: :sm` après le nom ; nombres `text-right tabular-nums`.
- Sous le tableau : `p.mt-3.text-sm.text-mute` « <total> établissements » (i18n `count:`), puis `ui_pagination(page:, pages:, param: :school_page)` (les autres paramètres de l'URL sont gardés par le composant).
- Lecture — `Queries::School::DrenaSchoolsQuery#call(drena_public_id:, period:, search: nil, page: 1, today: Date.current)` → `Page(drena, rows, page, pages, total)`, `SchoolRow(public_id, name, status, classrooms_count, teachers_count, students_count, active_students_count)` :
  - DRENA inconnue → `nil` (le contrôleur ne rend pas `_schools`, comme la vue nationale) ;
  - établissements de la DRENA dont `status = 'active'` **ou** qui ont au moins une classe active de l'année, un enseignant rattaché à titre principal ou un élève placé ;
  - chiffres : **les définitions de `TeamDashboardQuery#drena_rows`**, établissement par établissement (classes actives de l'année ; enseignants à école principale, non anonymisés ; élèves placés ; élèves placés ayant commencé une session dans la période) ;
  - recherche : `Queries::Shared::TextSearch` sur `schools.name` ;
  - tri `students_count DESC, schools.name, schools.id`, `PER_PAGE = 25` ;
  - **un nombre fixe de requêtes** (le total, puis une page aux chiffres calculés par sous-requêtes ou agrégats groupés), jamais une par établissement ; aucun cache (7 et 30 jours lus en direct ; l'année non plus : la page d'établissements n'entre pas dans le cache de l'ADR-0062).

**Tokens** : ceux de l'UDR-0005 seulement ; aucune valeur arbitraire, aucun attribut `style`.

**Comportement**
- Barre latérale, page Référentiel, liens de DRENA, recherche et pages d'établissements : navigations Turbo de la page entière. Aucun Turbo Stream, aucun toast.
- `table-filter` n'appelle jamais le serveur.
- Le cache des chiffres de l'année (ADR-0062) ne change pas ; `CACHE_VERSION` reste 1.

**États obligatoires**
- Menu « Plus » : fermé par défaut ; ouvert, focus sur la première entrée (contrôleur `dropdown`).
- Recherche de DRENA : champ masqué sans JavaScript ; aucune correspondance → « Aucune DRENA ne correspond. ».
- « Par établissement » : DRENA sans établissement listé → `ui_empty_state` « Aucun établissement actif dans cette DRENA », icône `building-library` ; recherche sans résultat → `ui_empty_state` « Aucun établissement ne correspond. » avec `ui_button` « Effacer ».
- Chargement : sans objet (pages rendues d'un bloc) ; Turbo pose `aria-busy` sur la page pendant la navigation.
- Erreur : page d'erreur commune.
- Refus : `/teams/referential` et le pilotage, 403 hors équipe.

**Accessibilité**
- Deux `nav` dans la barre latérale, nommées « Navigation principale » et « Configuration » ; une seule barre du bas.
- « Plus » : motif « menu button » (`aria-haspopup`, `aria-expanded`, `aria-controls`), nom accessible qui énumère les entrées ; cible ≥ 48 px (`min-h-tap`).
- Champ de recherche de DRENA avec `label` visible, résultat annoncé (`aria-live`).
- Tableaux : `caption`, `th scope="col"`, `th scope="row"` ; le lien de la DRENA a un complément `sr-only`.
- À 390 px : la barre du bas tient ses 5 cases ; les tableaux défilent dans leur carte, la page jamais (`scrollWidth` ≤ largeur de la fenêtre).

## 4. Conséquences

- Une destination de configuration s'ajoute à l'équipe par une ligne de `SECONDARY_DESTINATIONS` et une clé de locale, jamais par un partial ; la carte et le menu « Plus » l'affichent tous deux.
- Un rôle sans liste secondaire n'a ni 2e carte de navigation ni « Plus » : élève, enseignant et direction gardent une barre du bas sans menu.
- La somme des établissements d'une DRENA égale sa ligne : toute nouvelle définition d'indicateur s'écrit une fois pour les deux lectures (ADR-0062).
- Interdit : un menu caché pour un autre rôle sans nouvelle UDR ; une fiche d'établissement depuis le pilotage (hors périmètre) ; un filtre de DRENA qui appelle le serveur ; une page d'établissements sans pagination.
