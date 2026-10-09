# UDR-0076 : Organisation des écrans élève — ordre de l'accueil, « Ma classe » de travail, question suivante sans requête
<!-- index
titre: Organisation des écrans élève : ordre de l'accueil, « Ma classe » de travail, question suivante sans requête
statut: Proposé
adr-lie: [0076](../adr/0076-politique-de-cache-reglee-sur-les-allers-retours.md), [0072](../adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md)
problematique: Accueil : classe, matières (bulles illustrées, pastille ambre de retard), annonces, à faire, activités ; « Ma classe » : cours des exercices assignés en carrousel, exercices assignés non faits et exercices traités au meilleur score, 3 lignes puis « Voir plus » ; la question suivante arrive avec le verdict, sans requête ni cache. Numéro 0075 pris par `feature/annonces-v2`. Amende UDR-0058 §3.3, 0011, 0022 §2.1
-->

| | |
|---|---|
| **Statut** | Proposé · §2.2 et §2.3 confirmés par le porteur le 2026-10-05 |
| **Date** | 2026-10-05 |
| **Chantier** | [`docs/chantiers/interface-eleve-organisation`](../../chantiers/interface-eleve-organisation/memo.md) |
| **ADR lié** | [ADR-0076](../adr/0076-politique-de-cache-reglee-sur-les-allers-retours.md) (allers-retours, aucun HTML en cache) · [ADR-0067](../adr/0067-budgets-de-temps-serveur-des-ecrans.md) (nombre fixe de requêtes) · [ADR-0072](../adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) (seul un exercice s'assigne) · [ADR-0054](../adr/0054-moteur-d-evaluation-soumission-et-cloture.md) (aucune proposition correcte montrée) |
| **Amende** | [UDR-0058](0058-accueil-eleve.md) §3.3 (famille ordinateur, ordre des sections) · [UDR-0011](0011-ma-classe.md) (amendement du 2026-10-02 « plus de cours assignés ») · [UDR-0022](0022-session-d-exercice.md) §2.1 (« Question suivante recharge seulement le frame ») |
| **Remplacé par** | — |

---

## 1. Contexte

Le porteur a fixé, le 2026-10-05, l'organisation de trois écrans de l'élève :

- **Accueil** (`/students`) : classe, matières, annonces, à faire, activités récentes, dans cet ordre.
- **« Ma classe »** (`/students/classroom`) : les cours assignés en carrousel, les exercices assignés (3, puis « Voir plus »), les exercices traités avec le score de l'élève (3, puis « Voir plus »).
- **Session** (`/sessions/:id`) : le rendu des réponses et des corrections doit être plus rapide, dans le respect de la politique de cache.

## 2. Décision

1. **L'accueil commence par la classe**, puis les matières de l'élève en bulles illustrées (comme « Niveaux » chez la direction et « Cours » chez l'enseignant), puis les annonces, « À faire » et l'activité. La grille des matières remplace la carte « Cours », qui ne faisait que mener au catalogue.
2. **« Ma classe » redevient la page du travail de la classe.** Un cours ne s'assigne plus (ADR-0072) : les « cours assignés » sont **les cours qui contiennent au moins un exercice assigné à la classe**. Ils défilent dans une bande horizontale, comme le carrousel d'annonces.
3. **Chaque exercice n'est dit qu'une fois sur « Ma classe »** (R6 de l'UDR-0057) : « Exercices assignés » garde ceux qui ne sont pas encore faits, « Exercices traités » tous ceux que l'élève a terminés, avec son **meilleur** score.
4. **La question suivante arrive avec le verdict.** Le Turbo Stream de la réponse porte, en plus du verdict et de la progression, la question suivante dans un `<template>`. « Question suivante » l'affiche sans requête. Une question coûte un aller-retour au lieu de deux. **Aucun cache** : ni fragment, ni ETag, ni `Cache-Control` public (ADR-0076 §4.1) ; la question jointe ne contient aucune proposition correcte (ADR-0054).

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Accueil (`classroom/student_homes/show`)

**Ordre** : `NavigationHelper::HOME_SECTIONS[:student]` vaut
`[[:classroom, "academic-cap"], [:subjects, "squares-2x2"], [:announcements, "megaphone"], [:todo, "clipboard-document-check"]]`,
puis la carte « Mes activités récentes » (`id: "student_home_activity"`, frame différé inchangé), toujours en dernier. La clé `:courses` disparaît de l'accueil élève.

- `:classroom` → `_classroom_card` inchangé.
- `:subjects` → `_subjects` (nouveau), décrit ci-dessous.
- `:announcements` → `communication/messages/_carousel` inchangé, seulement si `@announcements.any_readable?` (UDR-0071 §3.5).
- `:todo` → la carte « À faire », suivie des fiches à revoir s'il y en a ; elle gagne `class: "min-w-0"` (une ligne avec échéance et bouton élargissait la page à 390 px).

**« Mes matières »** — `classroom/student_homes/_subjects`, locals `(subjects:, late_slugs:, icon:)` :
- `ui_card title: « Mes matières », icon: "squares-2x2", id: "student_home_subjects"`, sans sous-titre.
- Avec au moins une matière : `nav#student_home_subject_bubbles[aria-label="Mes matières"]` > `ul.grid.grid-cols-4.gap-y-4.sm:grid-cols-6` > un `li` par matière :
  `ui_subject_bubble label: <nom>, href: courses_path(material: <slug>), illustration: subject_illustration(<slug>), id: "subject_<slug>"`.
  - Si `<slug>` est dans `late_slugs` : `signal: :warning` (pastille ambre `bg-warning`, ajoutée à `ComponentsHelper::SIGNAL_DOTS`) et `sr_suffix: « , exercice en retard »`. Jamais de compteur (charte §9).
- Sans matière : `ui_empty_state title: « Aucune matière pour l'instant », icon: "squares-2x2"`.
- Pied de carte (`card.footer`) : `ui_button « Tous les cours », href: courses_path, variant: :ghost, size: :sm, icon_end: "arrow-right"` — comme l'accueil enseignant.

**Données** — `StudentHomeQuery::Row` gagne `subjects` : `SubjectRow(slug, name)`, les matières ayant au moins un cours **publié** du niveau de l'élève (`AudienceFilter`), sans doublon, dans l'ordre de la charte (Maths, Physique-Chimie, SVT, Français, Histoire-Géo, EDHC, Philosophie), puis les autres par nom. Une seule requête de plus.

### 3.2 « Ma classe » (`classroom/student_classrooms/show`)

Hiérarchie, du haut vers le bas, dans `div.grid.gap-5` :

1. **`#student_classroom_header`** : inchangé (UDR-0011 et ses amendements).
2. **« Cours assignés »** — `ui_card title: « Cours assignés », icon: "book-open", id: "student_classroom_courses"`.
   - Badge « N cours » (`brand`, `sm`) dans `card.actions` dès 1 cours.
   - La bande : `section` sous le contrôleur `communication--carousel` (même contrôleur et mêmes cibles que le carrousel d'annonces, UDR-0071 §3.5 : `track`, `pager`, `dot`).
     - `ul.scrollbar-none.flex.snap-x.snap-mandatory.gap-3.overflow-x-auto.motion-safe:scroll-smooth[data-communication--carousel-target=track][aria-label="Cours assignés"]`.
     - Un `li.shrink-0.basis-3/4.snap-start.sm:basis-1/3` par cours > `_course_card`.
     - Points de pagination (`pager`, `hidden` jusqu'à 2 cartes, `aria-hidden`), écrits comme ceux des annonces.
   - La carte porte `class: "min-w-0"` : case de la grille, elle prendrait sinon la largeur de sa bande et la page défilerait en largeur à 390 px.
   - **Carte d'un cours** (`_course_card`, locals `(course:)`) : `li#course_<slug>` > un lien `course_path(slug)` sur toute la carte, `flex h-full flex-col gap-3 rounded-card border border-line bg-white p-4`, `hover:border-brand`, focus `outline-brand` ; dedans : la pastille ronde teintée de la matière (`illustration.tint`, `size-12`, image décorative `size-8`), le nom (`font-display font-extrabold`, `line-clamp-2`), `ui_subject_badge` de la matière (`sm`), puis « N exercices assignés » (`text-xs text-mute`).
   - Vide : `ui_empty_state title: « Aucun cours assigné pour l'instant », description: « Les cours des exercices que tes enseignants assignent à ta classe apparaîtront ici. », icon: "book-open"`.
   - Ordre : le cours dont un exercice a été assigné le plus récemment d'abord.
3. **« Exercices assignés »** — `ui_card title: « Exercices assignés », icon: "clipboard-document-check", id: "student_classroom_assigned", data: ui_reveal_data` (avec au moins une ligne).
   - Les exercices assignés **non terminés**, dans l'ordre de « À faire » (UDR-0062 §3.2).
   - `ul.-mx-5.divide-y.divide-line.border-t.border-line.sm:-mx-6` > `_assigned_exercise` (locals `(exercise:, index:)`), `ui_reveal_item(index)` : 3 lignes visibles, les suivantes `hidden`, puis `ui_reveal_more`.
   - Ligne : un lien `exercise_path(public_id)` sur toute la ligne (`min-h-tap`, `hover:bg-mist`, focus `outline-brand`) : titre (`truncate font-medium`), puis `ui_subject_badge` et `due_badge(due_on)` ; chevron à droite. **Aucun bouton** : « Ma classe » n'a pas d'action principale (UDR-0057 R1).
   - Vide : `ui_empty_state title: « Rien à faire pour l'instant », description: « Les exercices que tes enseignants assignent à ta classe apparaîtront ici. », icon: "clipboard-document-check"`.
4. **« Exercices traités »** — `ui_card title: « Exercices traités », icon: "check-circle", id: "student_classroom_treated", data: ui_reveal_data` (avec au moins une ligne).
   - Une ligne par exercice terminé au moins une fois (sessions `completed`, standard ou de remédiation), de son niveau ; la plus récemment terminée d'abord.
   - Un exercice dépublié ou archivé après coup **reste** dans la liste : c'est le travail de l'élève, comme « Mes activités récentes » de l'accueil, et son résultat reste ouvert (`ReadSessionPolicy`).
   - Ligne (`_treated_exercise`, locals `(exercise:, index:)`) : un lien `exercise_session_result_path(last_session_public_id)` sur toute la ligne ; à gauche, la pastille `size-12 rounded-ln` de la note **meilleure** (`grade_label(best_score_percent)`), `bg-success-soft text-success` au-dessus du seuil de passage, sinon `bg-mist text-ink` (jamais d'ambre ni de rouge pour une note, charte §5) ; au milieu le titre (`truncate`) et « Meilleur score · <maîtrise> » (`text-xs text-mute`) ; chevron à droite.
   - 3 lignes puis « Voir plus », comme ci-dessus.
   - Vide : `ui_empty_state title: « Aucun exercice traité pour l'instant », description: « Termine un exercice pour retrouver ici ton meilleur score. », icon: "check-circle"`.

**Données** — `StudentClassroomQuery::Row` gagne `courses`, `assigned_exercises`, `treated_exercises`, en un nombre fixe de requêtes quel que soit le volume (ADR-0067). `assigned_exercises` réutilise la lecture de l'accueil (`StudentHomeQuery#assigned_exercises`), filtrée sur `completed_count.zero?`.

**Aucun frame différé** : la page reste à un aller-retour (ADR-0076 §4.2).

### 3.3 Session (`assessment/question_attempts/create`, `assessment/exercise_sessions/_feedback_card`)

- Le stream `create` garde ses deux `replace` (`question` par le verdict, `progress_bar`).
- Si une question suit, `_feedback_card` reçoit `next_question:` (`@play.next_question`, nil à la dernière réponse) et rend, à la fin de la carte `#feedback-card` :
  `<template data-assessment--next-question-target="question">` contenant `_question_card` de cette question (`form: nil`). Le `<template>` n'est pas rendu par le navigateur et n'est pas lu par un lecteur d'écran.
- La carte du verdict porte alors `data-controller="assessment--next-question"`. Le bouton « Question suivante » garde `href: exercise_session_path(...)` (repli sans JavaScript, et navigation du frame) et gagne `data-action="assessment--next-question#show"`. Il porte toujours `data-turbo-prefetch="false"` : la question est déjà là, le préchargement au survol coûterait une requête pour rien.
- `assessment--next-question#show` : s'il a une cible `question`, il annule la navigation, remplace `turbo-frame#question` par celui du `<template>`, puis donne le focus à la `legend` de la question (`tabindex="-1"` posé par le contrôleur). Sans cible, il laisse le lien naviguer.
- Dernière réponse : pas de `<template>` ; « Voir mon résultat » inchangé (`_top`, un aller-retour).
- La page `GET /sessions/:id` reste le repli et la reprise (AS-08) : inchangée.
- Sans JavaScript, la réponse redirige vers la session, qui montre déjà la question suivante : le verdict n'est pas affiché et le lien n'est pas atteint (comportement antérieur, inchangé).
- **Interdits** : `cache`, `fresh_when`, `stale?`, `expires_in` dans ces contrôleurs et ces vues (l'ETag faible que Rails pose sur toute réponse reste, il ne vaut jamais 304) ; aucune colonne `correct` lue pour la question jointe (`SessionPlayQuery::Answer` n'en a pas).

### 3.4 États obligatoires

| Écran | Vide | Chargement | Erreur | Succès |
|---|---|---|---|---|
| Accueil, matières | état vide + « Tous les cours » | rendu serveur, pas de chargement | — (lecture seule) | bulles |
| « Ma classe », trois sections | état vide de chaque section | rendu serveur | — (lecture seule) | bande, listes à 3 lignes |
| Session, question suivante | — | aucun : la question est déjà là | question déjà répondue ailleurs : refus sans écriture de l'ADR-0054 (réponse 200 : toast « déjà répondue », puis rafraîchissement vers l'état réel) | la question s'affiche, focus sur son énoncé |

### 3.5 Accessibilité

- Bulles : nom accessible « <matière> », ou « <matière>, exercice en retard » ; la pastille est `aria-hidden`.
- Bande des cours : `ul[aria-label="Cours assignés"]`, chaque carte est un lien dont le nom est son texte visible ; défilement au clavier par Tab (les liens), au doigt par glissement.
- Listes : « Voir plus » annonce « N lignes de plus affichées » (`aria-live="polite"`, contrat partagé du `reveal`).
- Note d'un exercice traité : la note est dite en texte (« 16/20 »), jamais par la couleur seule.
- Question suivante : focus sur l'énoncé de la nouvelle question.
- Cibles ≥ 44 px (`min-h-tap`).

## 4. Conséquences

- L'UDR-0058 §3.3 change d'ordre et perd la carte « Cours » ; l'amendement « plus de cours assignés » de l'UDR-0011 est levé, sous une autre définition des cours assignés ; l'UDR-0022 §2.1 (« recharge seulement le frame ») devient « affiche la question jointe, sans requête ».
- La famille téléphone de l'UDR-0058 §3.2 reste à faire ; elle devra garder cet ordre.
- Une session coûte, par question, un aller-retour. La page `GET /sessions/:id` n'est plus demandée qu'à l'arrivée, à la reprise ou sans JavaScript.
- Le contrôleur `communication--carousel` sert désormais deux bandes. S'il change, les deux se vérifient.
