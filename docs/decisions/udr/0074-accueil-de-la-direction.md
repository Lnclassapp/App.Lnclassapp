# UDR-0074 : Accueil de la direction — établissement, niveaux à pastille, annonces, activité récente

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-04 |
| **Chantier** | [`docs/chantiers/accueil-direction`](../../chantiers/accueil-direction/prd.md) |
| **ADR lié** | [ADR-0065](../adr/0065-espace-direction-simple-en-lecture-seule.md) (définitions du travail des élèves, inchangées) · [ADR-0078](../adr/0078-annonces-trois-auteurs-classes-ciblees-et-retrait.md) *(chantier `annonces`, amendé par la décision D-A1 du porteur)* |
| **Amende** | [UDR-0052](0052-espace-direction-simple.md) §2.1, §2.2, §3 « Page Travail des élèves » · [UDR-0006](0006-shell-applicatif-par-role.md) (navigation `school_admin`) · [UDR-0056](0056-gestes-de-la-direction.md) §3.1 (première destination) |
| **S'appuie sur** | [UDR-0070](0070-inscription-de-la-direction-et-comptes-direction.md) §3.3 (bandeau d'arrivée, conservé) · [UDR-0005](0005-design-system-fondateur.md) (tokens) · [UDR-0069](0069-accueil-enseignant-par-niveau-et-assignation-depuis-le-catalogue.md) §3.3 (bulles, illustrations) · [UDR-0071](0071-annonces.md) §3.5 (carrousel) · [UDR-0054](0054-finitions-d-interface.md) (retour, infobulles) |
| **Remplacé par** | — |

---

## 1. Contexte

La direction arrive sur « Travail des élèves », un tableau d'une ligne par classe, de la 6ème à la Tle. Il ne dit pas ce qui demande son attention (une classe sans enseignant, une classe qui ne rend pas ses devoirs), il oblige à faire défiler toutes les classes pour en comparer trois, et il n'a aucune place pour une annonce de l'équipe ni pour ce qui vient de se passer. Elle consulte surtout au téléphone.

## 2. Décision

1. **Un vrai accueil en quatre sections**, dans cet ordre : « Établissement », « Niveaux », « Annonces », « Activité récente ». L'UDR-0052 avait dit « pas d'accueil » ; le porteur en veut un (2026-10-04).
2. **La carte « Établissement » dit d'abord ce qui demande attention** : trois chiffres, puis des alertes d'une ligne, chacune vers l'endroit où l'on agit. Sans alerte, « Rien à signaler » : la direction sait qu'elle a tout vu.
3. **Les niveaux sont des bulles**, comme les cours de l'enseignant (UDR-0069) : une bulle par niveau qui a des classes, avec une **illustration propre au niveau**. Une bulle mène à la page du niveau.
4. **La page d'un niveau montre des cartes de classe**, pas un tableau : chaque carte porte l'illustration du niveau, ses chiffres, et mène à la page de la classe. L'UDR-0052 avait choisi le tableau pour comparer ; ici, la comparaison passe par **la pastille**.
5. **Une pastille rouge, jaune ou verte** sur le rond de chaque classe et de chaque niveau, comme une notification : le **taux de rendu** à seuils fixes (≥ 70 % vert, 40 à 69 % jaune, < 40 % rouge), absente quand le taux n'est pas calculé. La couleur n'est jamais seule : le taux est écrit sur la carte, dit dans le nom accessible de la bulle, et expliqué par une légende.
6. **« Annonces » est le carrousel de l'élève** (UDR-0071 §3.5), **en lecture seule : sans croix** (décision du porteur du 2026-10-04 ; D-A1, qui rendait tout masquable, n'a pas été appliquée par le chantier `annonces`).
7. **« Activité récente » se charge en différé**, comme celle de l'élève : la page s'affiche sans l'attendre.
8. **« Travail des élèves » devient « Accueil »** dans la navigation, à la même adresse.

**Écart assumé avec la charte** (`lnclass-design-system` §5 : « ambre = urgence, et rien d'autre », jamais de rouge pour juger un résultat) : **demandé par le porteur** pour comparer les classes. L'écart est **propre à l'espace direction** : il juge le travail d'une classe, jamais la note d'un élève, et aucun écran d'élève ou d'enseignant n'emploie ces pastilles.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Navigation

- `NavigationHelper::DESTINATIONS[:school_admin]` = `[ [ :home, :school_admin_classrooms_path, "home" ], [ :teachers, :school_admin_teachers_path, "user-group" ], [ :school, :school_admin_school_path, "building-library" ] ]` (si le chantier `annonces` a déjà ajouté son entrée, elle reste à sa place). Libellé : `shared.navigation.home` (« Accueil », existant). La clé `shared.navigation.student_work` est supprimée.
- `content_for :nav_key, "home"` dans `school_admin/classrooms/index`, `school_admin/classrooms/show`, `school_admin/levels/show` et `school_admin/departed_students/index` (au lieu de `"student_work"`).
- `HomeDestination` (`school_admin_classrooms`) : inchangé.

### 3.2 Accueil — structure (`school_admin/classrooms/index`)

- `page_title t(".page_title")` → « Accueil » (titre complet « Accueil · Direction · Lnclass », mécanique existante).
- `ui_page_header title: t(".greeting", name: shell_user.first_name)` → « Bonjour, Fatou », sans sous-titre (le nom de l'établissement est dans la carte : dit une fois).
- Sous l'en-tête, **inchangé**, le bandeau d'arrivée des directions `#staff_arrivals` de l'UDR-0070 §3.3 (`@arrivals`, directions arrivées depuis moins de 7 jours ; rendu, locale `index.arrivals.*` et tests repris tels quels). *Constat au merge de `Develop` du 2026-10-04 : le bandeau est arrivé avec le chantier `inscription-direction` pendant ce chantier.*
- Puis `div.grid.gap-5`, dans l'ordre :
  1. `render "school_card", home: @home` (§3.3) ;
  2. `render "levels", home: @home` (§3.4) ;
  3. `render "communication/messages/carousel", carousel: @announcements` **si** `@announcements&.any_readable?` (§3.10) ;
  4. la carte d'activité (§3.11).
- Lecture : `@home = Queries::School::DirectionHomeQuery.new.call(school_id: current_actor.school_id)` → `Home(school_name, school_type, school_active, school_year, figures, alerts, levels)` :
  - `figures` : `Figures(classrooms, students, teachers)` ; `classrooms` = classes actives de l'année ; `students` = élèves **distincts** présents dans ces classes (adhésion non quittée, compte non anonymisé) ; `teachers` = `SchoolTeachersQuery#call(...).teachers.size` (même définition que la page « Enseignants »).
  - `alerts` : `[Entities::School::DirectionAlerts::Alert(kind, names, others, count)]`, produit par `Entities::School::DirectionAlerts.call(school_active:, classrooms:, teachers_without_classroom:)` où `classrooms` = `[ClassroomFacts(name, students_count, teachers_count, submission_rate)]` triées comme les classes (niveau, puis nom). Ordre et règles en §3.3.
  - `levels` : `[LevelBubble(slug, name, classrooms_count, submission_rate)]`, niveaux ayant au moins une classe active de l'année, triés par `levels.position` ; `submission_rate` = `round(Σ devoirs rendus × 100 / Σ (élèves × devoirs))` sur les classes du niveau, `nil` si le dénominateur vaut 0. Les sommes partent de `StudentWorkQuery::ClassroomRow#submitted_count`, `students_count`, `assignments_count`.
  - Un nombre fixe de requêtes, quel que soit le nombre de classes (≤ 12, test de comptage).
  - **Gardé 5 minutes** par établissement et par année scolaire (ADR-0065, amendement du 2026-10-04, AD-23) : les chiffres, les alertes et les pastilles peuvent avoir jusqu'à 5 minutes de retard. Aucune mention à l'écran. Le bandeau d'arrivée et l'activité restent en direct.

### 3.3 Carte « Établissement » (`school_admin/classrooms/_school_card`)

- `ui_card id: "direction_home_school", title: home.school_name, subtitle: t(".subtitle", type: t("school_types.#{home.school_type}"), year: home.school_year), icon: "building-library"`.
- **Chiffres** : `ul#direction_home_figures.grid.grid-cols-3.gap-2.sm:gap-3` de trois `li.min-w-0.rounded-ln.bg-mist.px-2.py-3.sm:px-3` (motif des tuiles de l'UDR-0049) : nombre en `block font-display text-xl font-extrabold tabular-nums sm:text-2xl`, libellé en `block text-xs text-mute sm:text-sm` (« classes » / « élèves » / « enseignants », pluriels i18n `one`/`other`). *Resserré sous `sm` après la phase 5 (constat R1) : à 360 px, « enseignants » en 14 px sortait de sa tuile.*
- **Alertes** : sous les chiffres, `h3.mt-5.mb-2.text-xs.font-semibold.tracking-wider.text-mute.uppercase` « À surveiller », puis `ul#direction_home_alerts.space-y-2` ; un `li#alert_<kind>.flex.items-start.gap-3.text-sm.text-ink` par alerte :
  - `span.grid.size-8.shrink-0.place-items-center.rounded-full.bg-warning-soft.text-warning` avec `ui_icon "exclamation-triangle", variant: :mini, size: :sm` (décoratif) ;
  - `span.min-w-0.flex-1` : la phrase (ci-dessous), puis, si l'alerte a un lien, `link_to` en `block min-h-tap inline-flex items-center font-medium text-brand-strong` avec la flèche `arrow-right` mini.
- **Ordre et contenu des alertes** (règle du domaine `DirectionAlerts`, chacune présente seulement si son compte > 0) :

  | `kind` | Condition | Phrase (`school_admin.classrooms.school_card.alerts.<kind>`) | Lien |
  |---|---|---|---|
  | `inactive` | `school_active` faux | « Votre établissement n'est pas actif : les enseignants ne peuvent pas s'y inscrire. » | « Voir l'établissement » → `school_admin_school_path` |
  | `without_teacher` | classe avec `teachers_count == 0` | one « 1 classe sans enseignant : %{names} » · other « %{count} classes sans enseignant : %{names} » | « Inviter des enseignants » → `school_admin_school_path(anchor: "school_link")` |
  | `without_students` | classe avec `students_count == 0` | « 1 classe sans élève : %{names} » · « %{count} classes sans élève : %{names} » | — |
  | `red_signal` | `WorkSignal.for(submission_rate) == :red` | « 1 classe rend moins de 40 % des devoirs : %{names} » · « %{count} classes rendent moins de 40 % des devoirs : %{names} » | — |
  | `teachers_without_classroom` | enseignants dont `classroom_names` est vide | « 1 enseignant n'a déclaré aucune classe » · « %{count} enseignants n'ont déclaré aucune classe » | « Voir les enseignants » → `school_admin_teachers_path` |

  `names` : les **trois premiers** noms (ordre des classes) ; `others` = compte − 3 si positif. Rendu : sans `others`, `names.to_sentence(words_connector: ", ", two_words_connector: " et ", last_word_connector: " et ")` ; avec `others`, `t(".alerts.names_more", names: names.join(", "), count: others)` → « 3ème 2, 4ème 1, 6ème 5 et 2 autres » (`one` : « et 1 autre »).
- **Aucune alerte** : à la place de la liste, `p#direction_home_all_clear.flex.items-center.gap-2.text-sm.text-success` avec `ui_icon "check-circle", variant: :mini, size: :sm` et « Rien à signaler ».
- **Pied** (`card.footer`) : `div.flex.flex-wrap.gap-x-4` de deux `link_to` (`inline-flex min-h-tap items-center gap-1 text-sm font-medium text-brand-strong`) : « Voir l'établissement » → `school_admin_school_path` ; « Anciens élèves » → `school_admin_departed_students_path` (`id: "departed-students-link"`, conservé de l'ancienne page).

### 3.4 Section « Niveaux » (`school_admin/classrooms/_levels`)

- `ui_card id: "direction_home_levels", title: t(".title"), subtitle: t(".subtitle"), icon: "squares-2x2"` → « Niveaux », « Les classes de chaque niveau et leur travail ».
- Vide (`home.levels.empty?`) : `ui_empty_state title: « Aucune classe cette année », description: « Ajoutez des classes depuis la page Établissement. », icon: "squares-2x2"` avec `ui_button` « Voir l'établissement » (`secondary`, `sm`) → `school_admin_school_path`.
- Sinon : `nav#direction_home_level_bubbles` `aria-label` « Vos niveaux » → `ul.grid.grid-cols-4.gap-y-4.sm:grid-cols-7` ; un `li` par niveau :
  `ui_subject_bubble label: level.name, href: school_admin_level_path(level.slug), illustration: level_illustration(level.slug), signal: Entities::School::WorkSignal.for(level.submission_rate), sr_suffix: <sr>, id: "level_#{level.slug}"`.
  `<sr>` = `t(".sr_level", count: level.classrooms_count)` (« , 1 classe » / « , %{count} classes ») suivi, si le taux existe, de `t(".sr_rate", rate: level.submission_rate)` (« , taux de rendu %{rate} % ») et de `t("school_admin.signals.#{signal}.sr")` (« , signal vert » / « jaune » / « rouge »).
- Sous la grille, la légende `render "school_admin/shared/signal_legend"` (§3.12), seulement si au moins une bulle a une pastille.

### 3.5 Bulle à pastille (`components/_subject_bubble`, `ui_subject_bubble`)

- Nouveau paramètre `signal: nil` (`nil`, `:green`, `:yellow`, `:red`) ; `ui_subject_bubble(label:, href:, illustration:, sr_suffix: nil, id: nil, signal: nil)`. Une valeur inconnue lève `ArgumentError` (comme les autres options des composants).
- Le rond de 60 px reçoit `relative`. Si `signal` : dedans, après l'image, `span.absolute.-top-0.5.-right-0.5.size-3.5.rounded-full.ring-2.ring-white` + `bg-signal-green` / `bg-signal-yellow` / `bg-signal-red`, `aria-hidden="true"`. Taille 14 px, anneau de la couleur de la carte (`ring-white` est remappé en mode sombre).
- Sans `signal`, le rendu est **strictement** celui de l'UDR-0069 (les bulles de l'enseignant ne changent pas).

### 3.6 Illustrations de niveau

- `app/helpers/school_admin/levels_helper.rb` (`SchoolAdmin::LevelsHelper`) : `LEVEL_ILLUSTRATIONS` et `level_illustration(slug)` → `ComponentsHelper::Illustration(path, tint)` ; un slug inconnu ou `nil` → `subjects/generique.svg` sur `bg-mist` (l'illustration de repli de l'UDR-0069).

| Slug | Fichier `app/assets/images/levels/` | Motif | Teinte |
|---|---|---|---|
| `6eme` | `6eme.svg` | crayon | `bg-tint-yellow` |
| `5eme` | `5eme.svg` | règle | `bg-tint-green` |
| `4eme` | `4eme.svg` | équerre | `bg-tint-lilac` |
| `3eme` | `3eme.svg` | diplôme (BEPC) | `bg-tint-indigo` |
| `2nde` | `2nde.svg` | loupe | `bg-tint-lavender` |
| `1ere` | `1ere.svg` | ampoule | `bg-tint-red` |
| `tle` | `tle.svg` | toque (BAC) | `bg-tint-pink` |

- Contenu **exact** de chaque fichier (couleurs de l'annexe de la charte, `viewBox 0 0 48 48`, aucun attribut `style`, aucune classe) :

```html
<!-- 6eme.svg -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><g transform="rotate(45 24 24)"><rect x="18" y="2" width="12" height="6" rx="2" fill="#ef3b45"/><rect x="18" y="7" width="12" height="25" fill="#ffb020"/><rect x="18" y="7" width="4" height="25" fill="#e2681c"/><path d="M18 32h12l-6 12z" fill="#ffe7a8"/><path d="M22 40h4l-2 4z" fill="#262626"/></g></svg>
<!-- 5eme.svg -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><g transform="rotate(-35 24 24)"><rect x="4" y="17" width="40" height="14" rx="3" fill="#4cc764"/><path d="M9 17v6M14 17v4M19 17v6M24 17v4M29 17v6M34 17v4M39 17v6" fill="none" stroke="#24934a" stroke-width="2" stroke-linecap="round"/></g></svg>
<!-- 4eme.svg -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path d="M8 42V6l36 36z" fill="#a24be8"/><path d="M15 35V23l12 12z" fill="#ead7fd"/><path d="M8 13h5M8 19h4M8 25h5M8 31h4" fill="none" stroke="#7b2bc4" stroke-width="2" stroke-linecap="round"/></svg>
<!-- 3eme.svg -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="5" y="9" width="38" height="24" rx="4" fill="#ffe7a8"/><rect x="11" y="15" width="20" height="3" rx="1.5" fill="#6f7cf2"/><rect x="11" y="21" width="13" height="3" rx="1.5" fill="#c7c9ff"/><path d="M30 33l-2 10 6-3.5 6 3.5-2-10z" fill="#1e1b9a"/><circle cx="34" cy="30" r="6.5" fill="#4f46e5"/><circle cx="34" cy="30" r="2.6" fill="#ffc83d"/></svg>
<!-- 2nde.svg -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="29" y="25" width="7" height="20" rx="3.5" transform="rotate(-45 32.5 35)" fill="#3a45c4"/><circle cx="20" cy="20" r="14" fill="#6f7cf2"/><circle cx="20" cy="20" r="9.5" fill="#c7c9ff"/><circle cx="16.5" cy="16.5" r="3" fill="#ffffff"/></svg>
<!-- 1ere.svg -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path d="M24 4a14 14 0 0 0-8.5 25.1V34h17v-4.9A14 14 0 0 0 24 4z" fill="#ffc83d"/><path d="M19 21l5 5 5-5" fill="none" stroke="#f39c12" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/><rect x="16" y="35" width="16" height="4" rx="2" fill="#ef3b45"/><rect x="18.5" y="40" width="11" height="4" rx="2" fill="#ffb3b6"/></svg>
<!-- tle.svg -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path d="M12 22v9c0 4.4 5.4 8 12 8s12-3.6 12-8v-9l-12 6z" fill="#e63fa8"/><path d="M24 7 3 18l21 11 21-11z" fill="#a3176f"/><path d="M41 20v12" fill="none" stroke="#ffc83d" stroke-width="2" stroke-linecap="round"/><circle cx="41" cy="34" r="2.6" fill="#ffc83d"/></svg>
```

- Les illustrations gardent leurs couleurs en mode sombre ; seule la teinte du rond change (tokens).

### 3.7 Tokens de signal

Dans `@theme` et dans les **deux** blocs sombres de `app/assets/stylesheets/application.tailwind.css` :

| Token | Clair | Sombre |
|---|---|---|
| `--color-signal-green` | `#1f9d55` | `#6fd69a` |
| `--color-signal-yellow` | `#b88700` | `#ffd34d` |
| `--color-signal-red` | `#d93a3a` | `#ff8a80` |

Ces trois tokens ne servent **qu'aux pastilles et à leur légende** de l'espace direction. Ils ne remplacent ni `success`, ni `warning`, ni `error`.

Chaque pastille garde **au moins 3:1** sur le blanc de son anneau, dans les deux modes (`test/design/dark_mode_test.rb`). *Le jaune clair `#f2b705` d'origine n'avait que 1,82 : remplacé par `#b88700` après la phase 5 (constat O5 du challenger).*

### 3.8 Page d'un niveau (`school_admin/levels/show`)

- Route `GET /school-admin/levels/:slug` → `SchoolAdmin::LevelsController#show`, `school_admin_level_path(slug)`.
- Lecture : `Queries::School::StudentWorkQuery#level(school_id: current_actor.school_id, slug: params[:slug])` → `LevelOverview(level_name, level_slug, students_count, classrooms)` (`students_count` : élèves présents **distincts** du niveau, comme l'accueil — constat O1 de la phase 5) (mêmes `ClassroomRow`, classes actives de l'année de ce niveau, triées par nom) ou `nil` (slug inconnu, ou aucune classe active de l'établissement dans ce niveau) → `render_not_found`.
- `page_title level.level_name` ; `content_for :nav_key, "home"`.
- `ui_page_header title: level.level_name, subtitle: t(".subtitle", classrooms: <n classes>, students: <n élèves>), back: { label: t(".back"), href: school_admin_classrooms_path }` → « 3ème », « 4 classes · 172 élèves » (`level.students_count`), retour « Accueil ».
- `ul#level_classrooms.grid.gap-4.sm:grid-cols-2.xl:grid-cols-3` d'un `render "classroom_card"` par classe, puis la légende (§3.12) si au moins une classe a une pastille.
- `_classroom_card` : `li#classroom_<public_id>` contenant **un seul lien** vers `school_admin_classroom_path(public_id)` couvrant la carte, `group flex h-full flex-col gap-4 rounded-ln border border-line bg-white p-4 transition hover:border-brand focus-visible:outline-2 focus-visible:outline-brand` :
  - ligne d'en-tête `div.flex.items-center.gap-3` : le rond `span.relative.grid.size-15.shrink-0.place-items-center.rounded-full` + `illustration.tint`, avec `image_tag illustration.path, alt: "", class: "size-10", "aria-hidden": true, loading: "lazy"` et, si signal, la pastille de §3.5 ; puis `div.min-w-0` : nom `p.truncate.font-display.text-lg.font-extrabold.text-ink`, et `span.sr-only` `t("school_admin.signals.#{signal}.label")` si signal (« Signal vert : 70 % des devoirs rendus ou plus », « Signal jaune : de 40 à 69 % des devoirs rendus », « Signal rouge : moins de 40 % des devoirs rendus ») ;
  - `ul.space-y-1.5.text-sm.text-mute`, quatre `li.inline-flex.w-full.items-center.gap-1.5` à icône mini décorative :
    - `users` : « 1 élève » / « %{count} élèves » / « Aucun élève » ;
    - `clipboard-document-list` : « 1 devoir donné » / « %{count} devoirs donnés » / « Aucun devoir donné » ;
    - `chart-bar` : « Taux de rendu : %{rate} % » (`span.font-medium.text-ink` pour le nombre) ou « Taux de rendu : — » (`—` `aria-hidden` + `sr-only` « non calculé ») ;
    - `academic-cap` : « Moyenne : %{value} % » (`span.font-medium.text-ink` pour le nombre, comme le taux) ou « Moyenne : — » (même rendu de « — ») ;
  - `span.mt-auto.inline-flex.items-center.gap-1.5.text-sm.font-medium.text-brand-strong` « Ouvrir la classe » + `arrow-right` mini (`transition group-hover:translate-x-0.5`).
- Le taux et la moyenne suivent les définitions et le seuil de 5 élèves de l'ADR-0065 (inchangés).

### 3.9 Page d'une classe — retour

- `school_admin/classrooms/show` : `back: { label: classroom.level_name, href: school_admin_level_path(classroom.level_slug) }` (au lieu de « Travail des élèves » → liste). Le reste de la page est inchangé.

### 3.10 Annonces

- `SchoolAdmin::ClassroomsController#index` : `@announcements = Queries::Communication::InboxQuery.new.carousel(reader:, now: Time.current)` avec `reader = Queries::Communication::ReadableMessages.new.reader_for(actor: current_actor)` (motif de `Classroom::StudentHomesController`, chantier `annonces`). Lu en direct, jamais gardé (ADR-0065, amendement du 2026-10-04).
- Vue : `render "communication/messages/carousel", carousel: @announcements, dismissible: false`, entre « Niveaux » et « Activité récente », seulement si `@announcements.any_readable?`. Cinq cartes au plus, ordre et lien « Toutes les annonces » de l'UDR-0071 §3.5.
- **Aucune croix** sur aucune carte : le carrousel de la direction est en lecture seule (décision du porteur du 2026-10-04, après le merge du chantier `annonces` sans la décision D-A1). Le local `dismissible:` du carrousel (vrai par défaut, l'accueil élève ne change pas) est ajouté pour cela ; une demande de masquage forgée par une direction reste refusée par la règle d'`annonces` (403, ADR-0078 §4.2, inchangée).
- La décision D-A1 (l'équipe seule rédige, toute annonce se masque) reste à appliquer par un chantier à part ; s'il ouvre le masquage à la direction, ce local passe à `true` ici.

### 3.11 Activité récente

- Sur l'accueil : `ui_card id: "direction_home_activity", title: « Activité récente », subtitle: « Les 30 derniers jours dans votre établissement », icon: "bolt"` ; corps : `turbo_frame_tag "direction_home_activity_feed", src: school_admin_activity_path, loading: :lazy, target: "_top"` contenant `ui_loading_state variant: :skeleton`.
- Route `GET /school-admin/activity` → `SchoolAdmin::ActivitiesController#show`, qui ne rend **que** le partial `school_admin/activities/_activity` (`layout: false`), dans le même `turbo_frame_tag "direction_home_activity_feed"`. En HTML seulement : tout autre format reçoit **406** sans lire la base (constat D1 de la phase 5).
- Lecture : `Queries::School::SchoolActivityQuery#call(school_id: current_actor.school_id, now: Time.current)` → au plus 10 `Event(kind, at, teacher_gender, teacher_last_name, teacher_anonymized, student_first_name, student_last_initial, exercise_title, classroom_name, classroom_public_id)`, du plus récent au plus ancien, sur `(now - 30 jours)..now` :
  - `assignment` : `classroom_assignments.assigned_at`, classe active de l'année de l'établissement ; auteur `assigned_by` ;
  - `student_joined` : `classroom_students.joined_at`, même périmètre de classes, élève non anonymisé ;
  - `teacher_joined` : `teacher_schools.created_at` de l'établissement, enseignant non anonymisé.
  - Au plus 4 requêtes.
- `_activity` :
  - vide : `ui_empty_state title: « Rien de nouveau ces 30 derniers jours », icon: "bolt"` ;
  - sinon, groupé par jour (fuseau `Africa/Abidjan`) : pour chaque jour, `h3.mt-4.first:mt-0.mb-1.text-xs.font-semibold.tracking-wider.text-mute.uppercase` (« Aujourd'hui », « Hier », puis « Mardi 29 sept. », charte §12), puis `ul.divide-y.divide-line` ; une ligne `li.flex.min-h-tap.items-center.gap-3.py-2` :
    - icône dans `span.grid.size-9.shrink-0.place-items-center.rounded-full.bg-mist.text-mute` : `clipboard-document-list` (devoir), `user-plus` (élève), `academic-cap` (enseignant) ;
    - `p.min-w-0.flex-1.text-sm.text-ink` : la phrase ; le nom de la classe est un lien `font-medium text-brand-strong hover:underline` vers `school_admin_classroom_path` ;
      - `assignment` : « %{teacher} a donné « %{exercise} » à %{classroom} » ; `teacher` = « M. Kouassi » / « Mme Kouassi » (genre `male`/`female`), ou « Un enseignant » si anonymisé ;
      - `student_joined` : « %{student} a rejoint %{classroom} » ; `student` = prénom + initiale du nom et point (« Awa K. ») ;
      - `teacher_joined` : « %{teacher} a rejoint l'établissement » (sans lien) ;
    - `time.shrink-0.text-xs.text-mute.tabular-nums` `datetime` ISO, texte « 10:42 ».
  - Erreur du frame : une panne de la base (`ActiveRecord::ActiveRecordError`) est journalisée (`Rails.error.report`, comme le compteur de lecture des articles, ADR-0074 §4.7) et le contrôleur répond **503** avec le même frame portant `ui_error_state`, dont « Réessayer » recharge l'accueil ; le reste de la page reste affiché. Toute autre erreur remonte. *(Précisé au Lot C : sans JavaScript nouveau, seule la réponse peut porter cet état.)*

### 3.12 Légende du signal (`school_admin/shared/_signal_legend`)

- `div.mt-4.flex.flex-wrap.items-center.gap-x-4.gap-y-1.text-xs.text-mute` : « Taux de rendu des devoirs » + `ui_info_tip t("school_admin.classrooms.tips.submission_rate"), label: « Taux de rendu des devoirs »` (texte existant), puis trois `span.inline-flex.items-center.gap-1.5` : `span.size-2.5.rounded-full.bg-signal-green` (`aria-hidden`) « 70 % et plus » ; `bg-signal-yellow` « de 40 à 69 % » ; `bg-signal-red` « moins de 40 % ».
- Locales : `config/locales/school_admin/signals.fr.yml` → `school_admin.signals.{green,yellow,red}.{label,sr,legend}` et `school_admin.signals.legend_title`.

### Tokens

Ceux de l'UDR-0005, plus les trois tokens `signal-*` (§3.7) et les teintes `tint-*` de l'UDR-0069. Aucune valeur arbitraire, aucun attribut `style`.

### Comportement

- Lecture seule, hors masquage d'une annonce (UDR-0071). Aucun JavaScript nouveau : les bulles et les cartes sont des liens, le frame d'activité est un frame paresseux de Turbo, le carrousel garde son contrôleur Stimulus (chantier `annonces`).
- Ouvrir un niveau, une classe : navigation Turbo de la page entière.

### États obligatoires

- **Vide** : aucune classe → « Niveaux » vide (§3.4), chiffres à 0, alertes calculées ; aucune annonce → pas de section ; aucune activité → « Rien de nouveau ces 30 derniers jours ».
- **Chargement** : seule l'activité se charge à part (squelette `ui_loading_state variant: :skeleton`) ; le reste arrive avec la page.
- **Erreur** : niveau inconnu ou sans classe → 404 ; autre rôle → 403 ; frame d'activité en erreur → `ui_error_state` dans le frame.
- **Succès** : la page elle-même. Aucun toast, hors masquage d'annonce.

### Accessibilité

- Un seul `h1` par page (le `ui_page_header`) ; les sections sont des `h2` (`ui_card`), les jours de l'activité des `h3`.
- Chaque pastille est `aria-hidden` et **toujours** doublée d'un texte : `sr_suffix` des bulles, `span.sr-only` des cartes de classe, taux écrit sur la carte, légende visible.
- Bulles, cartes, liens d'alerte et lignes d'activité : cibles ≥ 48 px (`min-h-tap`). À 375 px, aucune page ne défile en largeur (test système).
- Focus visible sur chaque lien (`focus-visible:outline-2 focus-visible:outline-brand`).

## 4. Conséquences

- L'UDR-0052 n'est plus la référence de la page d'arrivée de la direction : son §2.1 (« pas d'accueil ») et son §2.2 (« des tableaux, pas des cartes ») cèdent pour cette page et pour la nouvelle page d'un niveau. La page d'une classe garde son tableau d'élèves.
- Les pastilles rouge, jaune, verte sont **réservées à l'espace direction** et au taux de rendu. Les employer ailleurs, ou pour une note d'élève, demande une nouvelle UDR.
- Les seuils 70 / 40 vivent dans le domaine (`Entities::School::WorkSignal`) : les changer est une décision du porteur, avec ses tests de bornes.
- La navigation `school_admin` commence par « Accueil » ; aucun rôle n'a plus d'entrée « Travail des élèves ».
- Toute nouvelle section de l'accueil, ou tout geste depuis ces pages, passe par une nouvelle UDR.
