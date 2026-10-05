# UDR-0077 : Organisation des écrans enseignant — accueil, catalogue, fiche essentielle, page d'une classe

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-05)* |
| **Date** | 2026-10-05 |
| **Chantier** | `docs/chantiers/interface-enseignant-organisation` |
| **ADR lié** | ADR-0067 (nombre fixe de requêtes), ADR-0072 (assignation et échéance), ADR-0078 (annonces) |
| **Remplacé par** | — |

Amende : UDR-0026 et UDR-0069 §3.1 (ordre et sections de l'accueil), UDR-0013 (catalogue), UDR-0015, UDR-0021 et UDR-0069 §3.8 (bascules de la fiche et de la page exercice), UDR-0028 (forme compacte de la bascule), UDR-0027 et UDR-0062 §3.4 (ordre de la page d'une classe).

---

## 1. Contexte

Sur téléphone, l'accueil de l'enseignant montre ses classes en grille (elles repoussent tout le reste), n'affiche pas les annonces qui lui sont destinées, et garde une section « Activités » marquée « Bientôt ». Le catalogue lui montre toutes les matières et tous les niveaux, sous un bloc de recherche qui remplit le premier écran. Sous chaque exercice d'une fiche, la ligne d'une classe (« Tle D 2 · Assigné · Pour jeu. 8 oct. · Retirer ») passe à la ligne au hasard. La page d'une classe commence par la liste complète des exercices et donne au code de récupération autant de poids qu'au nom de l'élève.

## 2. Décision

L'enseignant suit l'organisation fixée pour l'élève (UDR-0076) : des sections dans un ordre fixe, des **bandes défilantes** plutôt que des grilles pour les objets qu'on parcourt (classes, cours), **3 lignes puis « Voir plus »** pour les listes (UDR-0057 R3), une seule action visible par ligne, le reste dans un menu ⋮.

- Accueil : classes, cours, annonces, activités. « Activités » devient **« Exercices à suivre »** : ce qui demande une action de l'enseignant, pas un fil de tout ce qui s'est passé.
- Catalogue : l'enseignant ne voit que les cours de **sa matière** aux **niveaux (et séries) de ses classes** de l'année. La recherche et les filtres disparaissent **sous 640 px pour tous les rôles** (décision du porteur) ; le catalogue filtré garde un lien « Tout voir ».
- Fiche : chaque classe est une **ligne compacte** — nom, échéance dessous, une commande à droite.
- Classe : cours en bande, exercices assignés, élèves ; le code de récupération passe dans un menu ⋮.

Bande plutôt que grille : sur un écran de 375 px une bande tient en une hauteur de carte quel que soit le nombre de classes, et le pli reste au même endroit. C'est la bande du carrousel d'annonces (UDR-0071 §3.5), déjà connue des utilisateurs.

## 3. Règles d'implémentation

### 3.1 Accueil enseignant (`/teachers`)

**Ordre** : `HOME_SECTIONS[:teacher]` = `classrooms`, `courses`, `announcements`, `activity`. Puis, inchangés, « Collègues en attente » et l'invitation (téléphone).

**Mes classes** — `ui_card` `#teacher_home_classrooms`, menu ⋮ « Modifier mes classes » inchangé.
- Vide : état vide existant.
- Sinon : `div[data-controller="communication--carousel"]` contenant :
  - `ul.scrollbar-none.-mx-1.5.flex.snap-x.snap-mandatory.overflow-x-auto.motion-safe:scroll-smooth[data-communication--carousel-target="track"][aria-label="Mes classes"]` ;
  - chaque `li#classroom_<public_id>` : `shrink-0 basis-3/4 snap-start px-1.5 sm:basis-1/3`, la liste en `-mx-1.5` sans `gap` (trois cartes entières à partir de 640 px ; aucune valeur arbitraire, UDR-0005), contenu de la carte inchangé (`_classroom_card`) ;
  - `div.hidden.justify-center.gap-1.5.pt-3[aria-hidden="true"][data-communication--carousel-target="pager"]` avec un point par classe, le premier `h-1.5 w-4 rounded-full bg-brand-strong`, les autres `h-1.5 w-1.5 rounded-full bg-line`.
- La carte englobante porte `min-w-0` (sinon la bande élargit la grille et la page défile en largeur).

**Cours** — inchangé (bulles de niveaux, UDR-0069 §3.3).

**Annonces** — `render "communication/messages/carousel", carousel: @announcements, dismissible: false`, seulement si `@announcements.any_readable?`. Lecture seule : le masquage est réservé à l'élève (ADR-0078 §4.2). Lecteur : `ReadableMessages#reader_for(actor:)`, carrousel : `InboxQuery#carousel`.

**Activités** — `ui_card` `#teacher_home_activity`, titre « Activités », sous-titre « Les exercices à suivre cette semaine », icône `bolt`.
- Donnée : `Queries::Classroom::TeacherFollowUpsQuery#call(teacher_id:, today:)`. Une ligne = une assignation active, d'une classe active de l'année où il enseigne, d'un exercice de **sa matière**, avec une échéance comprise entre `today - 14` et `today + 7` inclus, et **au moins un élève présent** qui ne l'a pas fait (« fait » et « présent » : `AssignmentFollowUpQuery`, ADR-0072 §4.4, ADR-0079 §4.1). Tri : échéance croissante, puis nom de classe, puis id. Nombre de requêtes fixe (3), quel que soit le nombre de classes.
- Vide : `ui_empty_state` titre « Rien à suivre pour l'instant », description « Les exercices assignés dont l'échéance approche apparaîtront ici. », icône `bolt`.
- Sinon : conteneur `data: ui_reveal_data` ; `ul.-mx-5.divide-y.divide-line.border-t.border-line.sm:-mx-6` ; chaque ligne `li#follow_up_<public_id>` avec `ui_reveal_item(index)` :
  - `relative flex items-center gap-3 px-5 py-4 active:bg-mist sm:px-6` ;
  - titre de l'exercice : lien étiré (`after:absolute after:inset-0`) vers `classroom_assignment_path(classroom_public_id, public_id)`, `truncate font-medium` ;
  - dessous, `text-sm text-mute` : nom de la classe · `due_badge(due_on)` ;
  - dessous, `text-sm` : « %{pending} élèves sur %{present} ne l'ont pas fait » (1 : « 1 élève sur %{present} ne l'a pas fait ») ;
  - à droite, chevron `chevron-right` `text-mute`.
  - `ui_reveal_more(total)` après la liste.

### 3.2 Catalogue (`/courses`)

- **Portée de l'enseignant** : `Queries::Catalog::TeacherAudienceQuery#call(teacher_id:)` → `Scope(audience: LevelAudience, material_id:)`, les (niveau, série) de ses classes **actives de l'année** et sa matière. `CourseCatalogQuery` reçoit `audience:` et `material_id:`. Audience vide → aucun cours ; état vide « Déclarez vos classes pour voir vos cours » / « Les cours de votre matière, aux niveaux de vos classes, apparaîtront ici. », bouton « Déclarer mes classes » vers `teacher_classrooms_path`.
- Filtres de l'enseignant (ordinateur) : pas de liste « Matière » ; « Niveau » et « Série » ne proposent que ceux de ses classes.
- **Téléphone, tous les rôles** : le formulaire `#courses-filters` porte `hidden sm:grid` (caché sous 640 px). Le total `#courses_total` est placé dans une rangée `flex items-center justify-between` qui, si un filtre est actif, contient aussi `link_to "Tout voir", courses_path, id: "courses_reset_mobile", class: "sm:hidden … min-h-tap"` (cible ≥ 48 px).
- Sous-titre de l'enseignant : « Les cours de %{material}, aux niveaux de vos classes. »
- Cartes de l'enseignant : sans badge de matière (R6 : sa matière est dite une fois, par le sous-titre) ; le badge du niveau reste.
- Le total `#courses_total` reste seul dans sa région `aria-live` ; « Tout voir » est un lien voisin, pas annoncé.

### 3.3 Fiche essentielle — lignes de l'enseignant

Dans `_exercise_progress` (branche non-élève) :
- Métadonnées de l'exercice : une ligne de texte `text-sm text-mute` « QCM · 10 questions » (au lieu de deux badges) ; le statut de l'équipe reste un badge.
- Bouton « Ouvrir » : `hidden sm:inline-flex` (le titre est déjà un lien).
- Classes cibles : `ul.mt-3.divide-y.divide-line.rounded-ln.border.border-line` nommée « Assigner « %{title} » à mes classes » ; chaque `li` contient la bascule en forme **compacte**, qui porte toute la ligne.
- Bascule compacte (`classroom/assignments/_toggle`, local `compact: true`) : même `id` (`assignment_<classe>_Exercise_<exercice>`), mêmes actions et `aria-label` ; `div.flex.items-center.justify-between.gap-3.px-3.py-2` :
  - à gauche `div.min-w-0` : nom de la classe `block truncate text-sm font-medium` ; si assignée avec échéance, dessous `block text-xs text-mute` `due_for_teacher(due_on)` ;
  - à droite, assignée : `ui_badge "Assigné", tone: :success, icon: "check", size: :sm` puis un bouton ✕ seul (`size-tap`, `rounded-full`, variante `ghost`), `aria-label` « Retirer « %{name} » de %{classroom} » ;
  - à droite, non assignée : bouton « + Assigner » `secondary sm` (ou le lien vers la modale des jours, inchangé).
- Le mode compact voyage avec la requête : paramètre `compact=1` sur les deux boutons et sur le lien de la modale des jours (champ caché du formulaire de la modale). Les réponses Turbo Stream (`create`, `archive`) rendent la bascule avec `compact: params[:compact].present?` : la ligne entière, échéance comprise, est remplacée. Ailleurs (page d'une classe, cours dans la classe), rien ne change.
- La page d'un exercice (« Assigner à mes classes », UDR-0069 §3.8) prend la même liste compacte.

### 3.4 Page d'une classe (`/classrooms/:id`)

**Ordre** : en-tête ; jours de séance (enseignant) ; **Cours** ; **Exercices assignés** ; **Élèves**.

**Jours de séance** (décision du porteur, 2026-10-05) — une rangée `flex items-center justify-between` : la phrase à gauche ; à droite, jours renseignés : `ui_dropdown label: "Actions sur les jours de séance", id: "classroom-session-days-menu"` avec `ui_dropdown_item "Modifier les jours", frame: "modal", icon: "pencil-square"` ; jours manquants : le bouton « Renseigner » reste visible (sans lui, les exercices n'ont pas de date limite). Classe archivée : ni menu ni bouton.

**Cours** — `section#classroom_courses` (`min-w-0`), titre inchangé ; vide inchangé ; sinon la bande de §3.1 (`communication--carousel`, `li.px-1.5.basis-3/4.sm:basis-1/3` portant une carte `div`), une carte par cours au contenu inchangé (`li#classroom_course_<slug>`), points de pagination.

**Exercices assignés** — inchangés ligne à ligne ; le conteneur porte `data: ui_reveal_data`, chaque `li` `ui_reveal_item(index)`, puis `ui_reveal_more(assignments.size)`.

**Élèves** — chaque ligne : avatar, nom, contact à gauche ; à droite le dernier score puis, si la classe est active, `ui_dropdown label: "Actions pour %{name}", id: "student-actions-<public_id>"` contenant `ui_dropdown_item "Code de récupération du PIN", href: account_pin_recovery_codes_path(public_id), method: :post, frame: "_top", icon: "key"`. La ligne reste en `flex-row` à toutes les tailles (`items-center`) ; le score est `text-right`.

### États obligatoires

| Surface | Vide | Chargement | Erreur | Succès |
|---|---|---|---|---|
| Bande des classes | état vide existant | rendu serveur, aucun | page d'erreur commune | bande + points |
| Activités | « Rien à suivre pour l'instant » | rendu serveur (3 requêtes) | page d'erreur commune | 3 lignes + « Voir plus » |
| Catalogue enseignant | « Déclarez vos classes… » ou « Aucun cours ne correspond » | frame `aria-busy` (existant) | état d'erreur du contrôleur `search` (existant) | cartes |
| Ligne de classe (fiche) | phrase `#assign_targets_none` (existante) | — | toast d'erreur existant, 422 | ligne remplacée par le stream |
| Bande des cours (classe) | état vide existant | — | page d'erreur commune | bande + points |

### Accessibilité

- Bandes : `ul` nommée (`aria-label`), points `aria-hidden` ; chaque carte reste un lien unique au focus visible.
- Activités : un seul lien par ligne (titre étiré), nom accessible = titre de l'exercice ; le chevron est décoratif.
- Bouton ✕ : cible `size-tap` (48 px), `aria-label` qui nomme l'exercice **et** la classe.
- Menu ⋮ d'un élève : `aria-label` qui nomme l'élève ; motif « menu button » de `ui_dropdown`.
- À 375 px : aucune barre de défilement horizontale de page ; la ligne d'une classe de la fiche tient sur une ligne (nom tronqué si besoin).

## 4. Conséquences

- L'accueil enseignant n'a plus de section « Bientôt » : toute section d'accueil montre une donnée réelle.
- Le catalogue de l'enseignant est restreint par lecture, pas par policy : un lien direct vers un cours d'une autre matière reste ouvert (hors périmètre, memo).
- Interdit désormais : une grille de classes ou de cours sur l'accueil enseignant ou la page d'une classe ; un bouton d'action secondaire (code de récupération) à côté de chaque élève ; l'échéance redite à la fois sous la classe et dans la bascule (R6).
