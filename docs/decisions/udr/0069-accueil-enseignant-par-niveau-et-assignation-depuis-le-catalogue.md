# UDR-0069 : Espace enseignant — accueil réordonné, cours par niveau enseigné, carte Parrainage, assignation depuis le catalogue ; niveau d'un cours assigné

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-03 |
| **Chantier** | [`docs/chantiers/reorganisation-equipe-enseignant`](../../chantiers/reorganisation-equipe-enseignant/prd.md) — critères RE-11 à RE-28 (RE-27 : niveau d'un cours assigné) |
| **ADR lié** | [ADR-0075](../adr/0075-niveau-d-un-cours-assigne-fige.md) (niveau d'un cours assigné) · [ADR-0063](../adr/0063-parrainage-demarrage-a-froid-et-mesure-du-k-factor.md) (lien et partages, inchangés) · [ADR-0072](../adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) (seul l'exercice s'assigne, échéance) · [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (amendement du 2026-10-01 : règle de niveau) · amende [UDR-0006](0006-shell-applicatif-par-role.md), [UDR-0013](0013-catalogue-et-page-cours.md), [UDR-0014](0014-formulaire-cours.md), [UDR-0015](0015-page-fiche-essentielle.md), [UDR-0021](0021-page-exercice.md), [UDR-0026](0026-accueil-enseignant.md), [UDR-0042](0042-actions-de-ligne-dans-un-menu.md), [UDR-0050](0050-inviter-un-collegue-et-croissance.md), [UDR-0062](0062-echeances.md) · composants [UDR-0005](0005-design-system-fondateur.md), [UDR-0065](0065-mode-sombre-par-les-tokens.md) (tokens sombres) · charte `lnclass-design-system` §9, §13 (bulles et illustrations) |
| **Remplacé par** | — |

---

## 1. Contexte

L'accueil enseignant met « Cours » en dernier, sous la forme d'un lien vers le catalogue complet que l'enseignant doit filtrer lui-même. « Modifier mes classes » occupe le pied de « Mes classes ». L'invitation des collègues est un bloc en bas de l'accueil. Depuis le 2026-10-02, un exercice ne s'assigne que depuis la page d'une classe : l'enseignant qui trouve un exercice dans le catalogue doit repartir de sa classe pour l'assigner. Enfin, l'équipe peut changer le niveau d'un cours déjà assigné : ses exercices se retrouveraient assignés hors niveau, dans des classes dont les élèves ne peuvent plus les ouvrir.

Le porteur a tranché (memo, G1 à G13) : sections « Mes classes », « Cours », « Activités » ; « Modifier mes classes » dans un menu ; « Cours » en bulles, une par couple niveau-série enseigné, à l'illustration de la matière (modèle de l'accueil élève) ; « Inviter » dans la grille, sans « Versement » ; une carte « Parrainage » dans la barre latérale sur grand écran, le bloc restant sur téléphone ; l'assignation depuis le catalogue, aux seules classes du bon niveau ; **aucune assignation hors niveau**, jamais (G12 révisée : il n'en existe aucune aujourd'hui ; G13 : le niveau d'un cours assigné ne change pas s'il sortait une classe de son niveau).

## 2. Décision

1. **Ordre** : « Mes classes », « Cours », « Activités » (`HOME_SECTIONS[:teacher]`). « Activité de vos classes » devient « Activités ».
2. **« Modifier mes classes » passe dans un menu ⋮** de l'en-tête de la carte : l'en-tête ne passe plus à la ligne à 375 px (motif de l'UDR-0042), et le pied disparaît. L'UDR-0042 gardait ce lien hors des menus ; le porteur l'y met.
3. **« Cours » est une grille de bulles** sur le modèle de l'accueil élève : une bulle par couple (niveau, série) distinct des classes actives de l'année, à l'illustration de la matière de l'enseignant, le niveau en libellé. Une bulle mène au catalogue filtré par niveau, série et matière. Puis la bulle « Inviter ». Un lien « Voir tout le catalogue » reste toujours.
4. **Le catalogue gagne un filtre « Série »**, avec la règle de l'élève (série vide ou cette série) : « Tle D » liste les cours de Tle communs à toutes les séries et ceux de la série D.
5. **Illustrations** : les 7 matières du modèle, choisies par le slug figé de la matière ; une illustration générique pour toutes les autres. Des fichiers SVG servis par Propshaft (`image_tag`), pas de sprite en ligne : rien à analyser dans chaque page, mise en cache par le navigateur, CSP inchangée.
6. **Parrainage** : sur grand écran, une carte compacte dans la barre latérale, chargée **en différé** (frame Turbo `loading: lazy`) : la barre latérale est masquée sous `lg`, donc le frame n'est jamais demandé sur téléphone, et aucune page enseignant ne paie la lecture du parrainage avant d'être affichée. Sur téléphone, le bloc « Inviter un collègue » de l'accueil reste ; il est masqué à partir de `lg`.
7. **Assigner depuis le catalogue** : sur la fiche essentielle et sur la page d'un exercice, l'enseignant voit une bascule (UDR-0028, UDR-0062 §3.4) **par classe à lui du niveau et de la série du cours**. La bascule, la modale des jours et les streams sont ceux de la classe, réutilisés tels quels. Aucune règle nouvelle : le refus serveur `other_level` existe.
8. **Le niveau d'un cours assigné** : le formulaire d'un cours refuse un niveau ou une série qui sortirait une classe assignée de son niveau, avec un message sous « Niveau » (ADR-0075). Aucun signal « hors niveau » ailleurs : le cas ne peut plus se produire.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Accueil — ordre et titres (`classroom/teacher_homes/show`)

- `NavigationHelper::HOME_SECTIONS[:teacher]` = `[ [ :classrooms, "user-group" ], [ :courses, "book-open" ], [ :activity, "bolt" ] ]`.
- `classroom.teacher_homes.show.activity_title` = « Activités » (sous-titre et état « Bientôt » inchangés).
- Après la grille des sections : `_pending_colleagues` (inchangé, toutes largeurs), puis le bloc d'invitation **dans** `div.lg:hidden` (§3.7).

### 3.2 « Mes classes » — menu ⋮

- `ui_card ... id: "teacher_home_classrooms" do |card|` : `card.actions { ui_dropdown label: t(".classrooms_menu"), id: "teacher-classrooms-menu" { ui_dropdown_item t(".edit_classrooms"), href: teacher_classrooms_path, icon: "pencil-square" } }`.
- Locale : `classroom.teacher_homes.show.classrooms_menu` = « Actions sur mes classes ».
- Plus de `card.footer`. Le menu est là même sans classe (l'état vide garde son texte).

### 3.3 « Cours » — bulles par niveau (`classroom/teacher_homes/_course_levels`)

**Lecture** — `Queries::Classroom::TeacherHomeQuery::Row` gagne `material_slug` et `course_levels` : `[CourseLevel(level_slug, series_slug, label)]`, couples (niveau, série) **distincts** des classes déclarées (`teacher_classrooms`), actives, de l'année scolaire courante ; `label` = nom du niveau, puis nom de la série s'il y en a une, séparés d'une espace (« 3ème », « Tle D ») ; tri par `levels.position`, puis série sans nom d'abord, puis nom de série. Une requête de plus au plus.

**Carte** — `ui_card title: t(".courses_title"), subtitle: t(".courses_subtitle", material: @home.material_name), icon:, id: "teacher_home_courses"` (plus de `href:` sur la carte) ; corps : `render "course_levels", home: @home, invite: @invite` ; `card.footer { ui_button t(".all_courses"), href: courses_path, variant: :ghost, size: :sm, icon_end: "arrow-right" }`.
- Locales : `courses_subtitle` = « Les cours de vos niveaux en %{material} » ; `all_courses` = « Voir tout le catalogue » ; `course_levels.label` = « Vos niveaux et actions » ; `course_levels.empty` = « Déclarez vos classes pour retrouver ici les cours de vos niveaux. » ; `course_levels.sr_level` = « , cours de %{material} » ; `course_levels.invite` = « Inviter ». `courses_action` est supprimée.

**`_course_levels`**
- Si `home.course_levels.empty?` : `p#teacher_home_courses_empty.mb-4.text-sm.text-mute` avec `course_levels.empty`.
- `nav#teacher_home_course_levels` `aria-label` `course_levels.label` → `ul.grid.grid-cols-4.gap-y-4.sm:grid-cols-6` :
  - un `li` par niveau : `ui_subject_bubble label: level.label, href: courses_path(level: level.level_slug, series: level.series_slug, material: home.material_slug), illustration: subject_illustration(home.material_slug), sr_suffix: t(".sr_level", material: home.material_name), id: "course_level_#{[level.level_slug, level.series_slug].compact.join('_')}"` (`series:` omis quand `nil`) ;
  - si `invite` : un dernier `li` : `ui_subject_bubble label: t(".invite"), href: teacher_invite_path, illustration: subject_illustration(:invite), id: "course_level_invite"`.

**Composant `ui_subject_bubble(label:, href:, illustration:, sr_suffix: nil, id: nil)`** — `components/_subject_bubble.html.erb` :
- `a` (`id`, `href`) classes `group flex min-h-tap flex-col items-center gap-1.5 rounded-ln px-0.5 text-center text-sm leading-tight font-medium text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand` ;
- `span.grid.size-15.place-items-center.rounded-full.transition.group-active:scale-95` + `illustration.tint` ; dedans `image_tag illustration.path, alt: "", class: "size-10", "aria-hidden": true, loading: "lazy"` ;
- `span` libellé (`break-words`), puis `span.sr-only` `sr_suffix` si donné.

**Illustrations** — `ComponentsHelper::SUBJECT_ILLUSTRATIONS` et `subject_illustration(slug)` → `Illustration(path, tint)` :

| Slugs reconnus | Fichier `app/assets/images/subjects/` | Teinte (`tint`) |
|---|---|---|
| `mathematiques`, `maths` | `maths.svg` | `bg-tint-indigo` |
| `physique-chimie`, `pc` | `physique-chimie.svg` | `bg-tint-lilac` |
| `svt`, `sciences-de-la-vie-et-de-la-terre` | `svt.svg` | `bg-tint-green` |
| `francais` | `francais.svg` | `bg-tint-yellow` |
| `histoire-geographie`, `histoire-geo`, `hg` | `histoire-geographie.svg` | `bg-tint-lavender` |
| `edhc` | `edhc.svg` | `bg-tint-pink` |
| `philosophie`, `philo` | `philosophie.svg` | `bg-tint-pink` |
| `:invite` (action) | `inviter.svg` | `bg-tint-red` |
| tout autre slug, `nil` | `generique.svg` | `bg-mist` |

- Les fichiers reprennent **à l'identique** les symboles `i-maths`, `i-pc`, `i-svt`, `i-fr`, `i-hg`, `i-edhc`, `i-philo`, `i-invite` de la charte (annexe), en `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">` autonome : chaque `class="c-…"` / `s-…` devient l'attribut de présentation équivalent (`fill="#4f46e5"`, ou `fill="none" stroke="#a3176f" stroke-width="1.6" stroke-linecap="round"`) ; le `?` de Philosophie : `font-family="Bricolage Grotesque, ui-sans-serif, sans-serif" font-weight="800"`. Aucun attribut `style`, aucune classe.
- `generique.svg` (livre fermé, couleurs de la marque) :
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="9" y="5" width="30" height="38" rx="4" fill="#0070b3"/><rect x="13" y="5" width="4" height="38" fill="#004e80"/><rect x="21" y="12" width="13" height="3" rx="1.5" fill="#ffffff"/><rect x="21" y="18" width="10" height="3" rx="1.5" fill="#7fd0ff"/><rect x="9" y="37" width="30" height="6" rx="2" fill="#e5f5ff"/></svg>`
- Les illustrations gardent leurs couleurs en mode sombre ; seule la teinte de la bulle change (tokens).

**Tokens** (`@theme` et les deux blocs sombres de `application.tailwind.css`) :

| Token | Clair | Sombre |
|---|---|---|
| `--color-tint-indigo` | `#dee5ff` | `#23284d` |
| `--color-tint-lilac` | `#f0dfff` | `#33224a` |
| `--color-tint-green` | `#e3ffdf` | `#18361d` |
| `--color-tint-yellow` | `#fff8d2` | `#3a3214` |
| `--color-tint-lavender` | `#f2f2ff` | `#252845` |
| `--color-tint-pink` | `#ffe1f3` | `#3d1a30` |
| `--color-tint-red` | `#fff0f0` | `#3d2023` |

### 3.4 Catalogue — filtre « Série » (`catalog/courses/index`)

- `Catalog::CoursesController::FILTERS = %i[level series material q]`.
- `CourseCatalogQuery#call(..., series: nil)` : appliqué **seulement avec un niveau** ; `series` présent → `courses.series_id IS NULL OR series.slug = :series` ; une série inconnue → aucun cours ; sans niveau, `series` est ignoré.
- Formulaire : pour l'enseignant et l'équipe (pas l'élève), une liste « Série » entre « Niveau » et « Matière » : « Toutes les séries », puis les séries distinctes de `filter_options.series_by_level`, par nom (`it.name`, `it.slug`), même gabarit et même `change->search#submit` que les autres. Locale `catalog.courses.index.filters.series` = « Série », `all_series` = « Toutes les séries ».
- Grille du formulaire : `lg:grid-cols-4` (la recherche garde toute la ligne : `sm:col-span-2 lg:col-span-4` ; les boutons `lg:col-span-1`).
- État vide filtré : l'existant (« Aucun cours ne correspond », « Effacer la recherche »).

### 3.5 Bulle « Inviter »

- Présente si et seulement si `@invite` (policy `InviteColleaguePolicy`, établissement principal actif) ; mène à `teacher_invite_path`.

### 3.6 Carte « Parrainage » de la barre latérale

- `shared/navigation/_sidebar`, après les cartes de navigation (UDR-0068 §3.2), **pour le rôle enseignant seulement**, et **pas** sur `teacher_invite_path` (la page porte déjà le bloc complet) : `turbo_frame_tag "sidebar_referral", src: teacher_invite_path, loading: :lazy, target: "_top", class: "mt-4 block"` contenant `ui_loading_state variant: :skeleton`. La règle est une donnée de `NavigationHelper` : `SIDEBAR_FRAMES = { teacher: [ [ "sidebar_referral", :teacher_invite_path ] ] }`.
- `Identity::ReferralsController#show` : si `turbo_frame_request_id == "sidebar_referral"`, rend `identity/referrals/_sidebar_card` (`invite: @invite`), **sans layout**, et rien d'autre ; sans invitation possible, le même frame **vide** (pas de 403 : le frame ne doit pas afficher d'erreur à un enseignant d'établissement inactif).
- `_sidebar_card` : `turbo_frame_tag "sidebar_referral"` → si `invite` : `section#sidebar_referral_card` `aria-labelledby="sidebar_referral_title"` (`rounded-card border border-line bg-white p-4 shadow-card`) :
  - ligne d'en-tête `flex items-center justify-between gap-2` : `h2#sidebar_referral_title` (`font-display text-base font-extrabold`) « Parrainage » ; si ambassadeur, `ui_badge "Ambassadeur", tone: :gold, size: :sm, icon: "trophy"` ;
  - `p#sidebar_referral_count.mt-1.text-sm.text-mute` : les textes du compteur de l'UDR-0050 (« Aucun collègue inscrit grâce à vous pour l'instant. », « 1 collègue inscrit grâce à vous », « N collègues inscrits grâce à vous ») ;
  - `p.mt-3.text-xs.font-semibold.tracking-wider.text-mute.uppercase` « Votre lien », puis `a#sidebar_referral_link` (`block truncate text-sm font-medium text-brand-strong`, `title` = le lien complet) ;
  - `div#sidebar_referral_actions.mt-3.grid.gap-2` sous `data-controller="identity--share"` avec **les mêmes valeurs** que `_invite` (`url`, `link`, `text`, `clipboard:copied->identity--share#recordCopy`) : `ui_button` « WhatsApp » (`brand`, `sm`, `full: true`, icône `chat-bubble-left-right`, `target="_blank"`, `rel="noopener"`, `identity--share#record`, canal `whatsapp`) ; `ui_copy_button` « Copier le lien » (`secondary`, `sm`) ; `ui_button` « Plus d'options » (`ghost`, `sm`, `full: true`) vers `teacher_invite_path`.
  - Les identifiants sont **préfixés `sidebar_referral_`** : le bloc de l'accueil (`#referral_link`, `#referral_count`, `#referral_share_actions`) reste dans le DOM à `lg`, masqué.

### 3.7 Bloc d'invitation de l'accueil — téléphone seulement

- `classroom/teacher_homes/show` : `<div class="lg:hidden"><%= render "identity/referrals/invite", invite: @invite %></div>`. La page « Inviter un collègue » (`identity/referrals/show`) garde le bloc à toutes les largeurs.

### 3.8 Assigner depuis le catalogue

**Lecture** — `Queries::Classroom::CatalogAssignmentTargetsQuery#call(teacher_id:, course_slug:, exercise_public_ids:, today: Date.current)` *(constat d'exécution : les pages n'ont que le slug du cours et les `public_id` des exercices)* → `Targets(scope_label, classrooms, states)` :
- `classrooms` : `[Target(public_id, name, needs_session_days)]`, classes de `teacher_classrooms` de l'enseignant, actives, de l'année scolaire courante, **du niveau du cours** et, si le cours a une série, **de cette série** ; tri par nom naturel (« 3ème 2 » avant « 3ème 10 », comme `TeacherHomeQuery`). `needs_session_days` : aucune ligne de jours de séance pour (enseignant, classe) (ADR-0072 §4.2).
- `states` : `{ [classroom_public_id, exercise_public_id] => State(assignment_public_id, due_on) }`, assignations **actives** seulement.
- `scope_label` : « <niveau> <série> » du cours (« Tle D », « 3ème »).
- Deux requêtes au plus, quel que soit le nombre d'exercices.

**Fiche essentielle** (`catalog/essentials/show`, `Catalog::EssentialsController`) : pour `current_actor.teacher?` seulement, `@targets` = la query ci-dessus (exercices **publiés** de la fiche) ; équipe et élève : `nil`.
- Au-dessus de la liste des exercices, si `@targets` et `@targets.classrooms.empty?` : `p#assign_targets_none.text-sm.text-mute` « Aucune de vos classes n'est en %{level}. ».
- `_exercise_progress` (branche non élève) reçoit `targets:` ; si `targets&.classrooms&.any?` et l'exercice est publié : sous la ligne, `ul.mt-3.space-y-2.sm:mt-0` `aria-label` « Assigner « %{title} » à vos classes », un `li.flex.items-center.justify-between.gap-3` par classe : `span.text-sm.font-medium.text-ink` le nom de la classe, puis `render "classroom/assignments/toggle"` (`classroom_public_id`, `assignable_type: "Exercise"`, `assignable_key: exercise.public_id`, `assignable_name: exercise.title`, `classroom_name: target.name`, `assignment_public_id` et `due_on` de `states`, `needs_session_days: target.needs_session_days`). Le bouton « Ouvrir » reste.
- Mise en page de la ligne : la colonne des bascules passe sous le titre sous `sm`, à droite à partir de `sm` (la ligne `li` existante est déjà `sm:flex-row`). Chaque `li` de classe est `flex-wrap`, la bascule dans un `div.max-w-full` : à 375 px, « Assigné · Pour … · Retirer » passe sous le nom de la classe au lieu de déborder.

**Page d'un exercice** (`assessment/exercises/show`, `Assessment::ExercisesController`) : pour l'enseignant, après l'en-tête, si l'exercice est publié : `ui_card title: « Assigner à mes classes », icon: "user-group", id: "exercise_assign"` ; corps : la même `ul` de classes et de bascules, ou la phrase « Aucune de vos classes n'est en %{level}. » (`p#exercise_assign_none`).

**Bascule** (`classroom/assignments/_toggle`) : nouveau local `classroom_name: nil`, passé aussi par la fiche dans la classe (`classroom/classroom_essentials/show`) pour que l'`aria-label` ne change pas après un stream. S'il est donné, les `aria-label` deviennent « Assigner « %{name} » à %{classroom} » et « Retirer « %{name} » de %{classroom} » (`assign_to_label`, `archive_from_label`) ; sinon ceux d'aujourd'hui. `create.turbo_stream` et `archive.turbo_stream` passent `classroom_name: @classroom.name`. Identifiant, streams, modale des jours, `return_to` et rafraîchissement par morphing : **inchangés** (UDR-0062 §3.4) ; ils fonctionnent sur toute page qui porte la bascule.

### 3.9 Formulaire d'un cours — niveau d'un cours assigné (`teams/courses/_form`)

- Aucun changement de balisage : le refus `:conflict` d'`UpdateCourse` (`errors: { level_slug: [:assigned_elsewhere] }`, ADR-0075) passe par le chemin existant `render_result … form: :edit` : 422, la modale se rouvre, `ui_field :level_slug` affiche l'erreur (`aria-invalid`, `aria-describedby`), les valeurs saisies sont gardées (UDR-0006, CRUD Hotwire ; UDR-0014).
- Message, à côté de `taken` dans `config/locales/teams/courses.fr.yml` : « Ce cours est assigné à des classes d'un autre niveau ou d'une autre série. Retirez ces assignations avant de le changer. »

**Tokens** : ceux de l'UDR-0005 et les sept teintes du §3.3 ; aucun attribut `style`, aucune valeur arbitraire, aucune couleur littérale dans une vue.

**Comportement**
- Accueil : lecture seule ; les bulles et « Voir tout le catalogue » sont des navigations Turbo.
- Carte Parrainage : un seul chargement par page, à partir de `lg` seulement ; liens du frame en `_top`.
- Bascules du catalogue : `button_to` POST ou lien vers la modale des jours (frame `modal`), streams `replace` de la bascule, toast, `refresh` quand les jours viennent d'être donnés.
- Aucun nouveau contrôleur Stimulus côté enseignant.

**États obligatoires**
- Accueil : sans classe (§3.3) ; « Activités » : « Bientôt » ; Parrainage : squelette pendant le chargement du frame, frame vide si l'invitation est fermée.
- Catalogue : aucune classe au bon niveau → phrase du §3.8 ; refus `other_level` (POST forcé) → toast d'erreur existant, 422.
- Formulaire d'un cours : refus de niveau → 422, erreur sous « Niveau », modale rouverte.
- Erreur serveur : page d'erreur commune ; un frame de parrainage en erreur garde son squelette (aucune information sensible n'en dépend).

**Accessibilité**
- Bulles : liens dont le nom accessible est « Tle D, cours de Mathématiques » (libellé + `sr-only`) ; illustrations `alt=""` ; cibles ≥ 48 px ; focus visible.
- Menu « Actions sur mes classes » : motif « menu button » du composant `ui_dropdown`.
- Carte Parrainage : `section` nommée par son titre ; bouton de copie annoncé par le toast existant.
- Bascules : `aria-label` qui nomment l'exercice **et** la classe (§3.8).
- À 375 px : l'en-tête de « Mes classes » ne passe pas à la ligne ; 4 bulles par rangée ; aucune barre de défilement horizontale.

## 4. Conséquences

- L'accueil enseignant n'affiche toujours aucun montant ; « Versement » est retiré (G1) et ne revient qu'avec une source de vérité du paiement.
- Toute matière nouvelle a une bulle (générique) sans code ; une illustration dédiée s'ajoute par un fichier et une ligne de `SUBJECT_ILLUSTRATIONS`.
- L'enseignant assigne un exercice depuis sa classe **ou** depuis le catalogue ; la règle de niveau reste unique, côté serveur.
- Le lien de parrainage vers d'autres établissements (référence de l'enseignant) reste hors périmètre (G2).
- Interdit : une assignation active hors niveau, par quelque chemin que ce soit ; une bascule d'assignation pour l'équipe au catalogue, une bascule vers une classe d'un autre niveau, un sprite SVG en ligne dans le shell, un identifiant HTML partagé entre la carte Parrainage et le bloc d'invitation.
