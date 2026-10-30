# UDR-0145 : Les exercices et les questions en cartes
<!-- index
titre: Exercices et questions en cartes
statut: Accepté
adr-lie: —
problematique: Un exercice s'affiche en quatre lignes différentes, sans matière ici, sans type là, sans action écrite ; les questions d'un exercice se suivent sans cadre ni format annoncé.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-30 |
| **Chantier** | `docs/chantiers/exercices-en-cartes` |
| **ADR lié** | — |
| **Remplacé par** | — |

Remplace, pour le rendu d'un exercice listé : l'UDR-0139 §3.4 (ligne de « Prépare interros »), l'UDR-0076 §3.2 et l'UDR-0086 §3.4 (lignes « Exercices assignés » et « Exercices traités » de « Ma classe »), le format de ligne de l'UDR-0077 §3.4 pour le bloc « Exercices assignés » de la classe de l'enseignant. Amende l'UDR-0138 §3.1 : les questions du sujet ne sont plus sur une seule feuille mais chacune dans sa carte ; l'énoncé garde la sienne. Ne touche pas l'UDR-0132 (carte « Prochain exercice » de l'accueil).

---

## 1. Contexte

L'élève, l'enseignant et l'équipe voient un exercice en quatre lignes de liste différentes. La matière manque sur la page d'une leçon, le type manque dans « Ma classe », l'action n'est écrite nulle part. Le porteur demande « les exercices en cartes, avec un design amélioré ». Dans l'écran d'un exercice, les questions se suivent sur une feuille : au téléphone, le numéro se perd et rien n'annonce le format (relier, ordonner, rédiger) avant les propositions.

## 2. Décision

**Une carte d'exercice unique**, un partial, nourri par un helper qui traduit chaque ligne de lecture en une même `Card`. La carte répond à trois questions, dans l'ordre de lecture : *de quoi s'agit-il* (pastille de matière, « Matière · Type », titre), *où j'en suis* (une pastille d'état : échéance, note, « À revoir » ou statut), *que faire* (un verbe : « Commencer », « Reprendre », « Voir ma copie », « Refaire », « Revoir », « Voir l'exercice », « Voir le suivi »). Toute la carte est un lien (lien étiré du titre) ; le verbe est écrit, plus seulement suggéré par une flèche.

Pourquoi des cartes en grille plutôt que des lignes : sur ordinateur, deux ou trois colonnes montrent toute la semaine sans défiler ; au téléphone, une colonne de cartes séparées se touche mieux que des lignes collées, et la pastille d'état garde sa place fixe en bas.

**Une carte par question** dans l'écran d'un exercice : numéro en pastille, format de la question, énoncé, propositions. Le format (« Relier », « Une seule réponse ») dit à l'élève quoi faire avant de lire. Pour un choix à plusieurs bonnes propositions, l'élève lit « Plusieurs réponses », jamais leur nombre.

Écarté : afficher sur la carte d'un exercice la liste des formats de ses questions (quatre étiquettes sur une carte de 2 lignes de titre : du bruit) ; une carte différente par rôle (on retomberait dans quatre rendus).

## 3. Règles d'implémentation

### 3.1 La carte d'exercice — `app/views/assessment/exercises/_card.html.erb`

**Données** — le partial reçoit `card:` (un `Assessment::ExerciseCardsHelper::Card`) et un bloc facultatif (rendu sous la carte, dans l'article : les bascules d'assignation de l'enseignant).

`Card = Data.define(:dom_id, :href, :title, :material_name, :material_slug, :type_label, :meta, :status, :action, :progress)`

- `dom_id` : l'`id` du `<li>`, celui qu'avait la ligne remplacée (`exercise-<public_id>`, `assignment_<public_id>`, ou `nil`).
- `href` : la destination, ou `nil` (carte sans lien ni action).
- `material_name` : `nil` sur la page d'une leçon (déjà dite dans l'en-tête de la page).
- `material_slug` : la pastille ; `nil` ou inconnu → l'illustration de repli (une carte montre toujours une pastille).
- `type_label` : « Fixation » ou « Évaluation » (`assessment.exercises.show.exercise_types.*`), ou `nil`.
- `meta` : texte court facultatif (« 6 questions »).
- `status` : HTML déjà rendu (un `ui_badge`, un `due_badge`, une note), ou `nil`.
- `action` : le verbe, ou `nil`.
- `progress` : `[done, total]` pour l'enseignant, ou `nil`.

**Structure**

```
<li id=dom_id class="min-w-0" {ui_reveal_item si index}>
  <article class="group relative flex h-full flex-col gap-3 rounded-card border border-line bg-white p-4 shadow-card
                  [si href] transition hover:border-brand/40 hover:shadow-lift">
    <div class="flex items-start gap-3">
      <span class="grid size-11 shrink-0 place-items-center rounded-full {tint}" aria-hidden> <img 28 px> </span>
      <div class="min-w-0 flex-1 space-y-1">
        [si material_name ou type_label] <p class="text-meta text-mute">Matière · Type</p>   (séparateur « · »)
        <h3 class="text-base leading-snug font-medium text-ink line-clamp-2 break-words">
          [si href] <a href class="after:absolute after:inset-0 after:rounded-card focus-visible:outline-none focus-visible:after:outline-2 focus-visible:after:outline-offset-2 focus-visible:after:outline-brand">titre</a>
          [sinon]   titre
        </h3>
        [si meta] <p class="text-meta text-mute">meta</p>
      </div>
    </div>
    [si progress] barre ui_progress role :teacher + « 20 / 27 faits » (tabular-nums)
    <div class="mt-auto flex min-h-8 items-center justify-between gap-3 border-t border-line pt-3">
      <div class="min-w-0">status</div>
      [si action et href] <span class="inline-flex items-center gap-1 text-sm font-medium text-brand-strong" aria-hidden="true">
                           action <icône arrow-right mini, group-hover:translate-x-0.5> </span>
    </div>
    [bloc] <div class="relative z-10">…</div>
  </article>
</li>
```

- Le `<li>` porte `data-bleed-keep` : une carte d'exercice reste toujours dans la marge, arrondie, au téléphone aussi (la règle `[data-bleed]` exclut `[data-bleed-keep] *`).
- Le titre est un `<h3>` : les listes sont sous un `<h2>` de section.
- Le pied de carte passe à la ligne (`flex-wrap`, `gap-x-3 gap-y-2`) : l'échéance et le verbe ne se touchent jamais à 390 px.
- Le verbe est `aria-hidden` : le nom accessible du lien reste le titre seul (la destination ne change pas avec le verbe ; les tests et les lecteurs d'écran trouvent l'exercice par son titre).
- Un seul lien par carte. Rien d'interactif hors du bloc ; le bloc est `relative z-10` pour passer au-dessus du lien étiré.

**Conteneur** — la liste qui accueille des cartes est un `<ul class="grid gap-3 sm:grid-cols-2">` (deux colonnes dès 640 px) ; en pleine largeur, la grille s'élargit avec l'écran : `xl:grid-cols-3 2xl:grid-cols-4` (page d'une leçon, §3.2 bis) ; « Exercices assignés » de la classe de l'enseignant, sur ordinateur, reste à 2 : il partage la ligne. Plus de `divide-y`, plus de cadre bordé autour de la liste.

**Le helper** — `app/helpers/assessment/exercise_cards_helper.rb`, une méthode par source :

| Méthode | Source | `href` | `status` | `action` |
|---|---|---|---|---|
| `exercise_card_for_assigned(row)` | « Ma classe », à faire (`StudentHomeQuery::ExerciseRow`) | l'exercice | `due_badge(row.due_on)` | « Reprendre » si `started_session_public_id`, sinon « Commencer » |
| `exercise_card_for_treated(row)` | « Ma classe », traités (`StudentClassroomQuery::TreatedRow`) | le résultat de la dernière session | la meilleure note sur 20 (vert dès `MASTERY_THRESHOLD`, encre en dessous) + « · Acquis / En difficulté » en `text-mute` | « Voir ma copie » |
| `exercise_card_for_lesson(row, material_slug:, team:)` | page d'une leçon (`PrepareInterrosQuery::ExerciseRow`) | l'exercice | élève : `:to_review` → `ui_badge "À revoir"` (warning, arrow-path) ; `:due` → `due_badge` ; `:score` → note (vert/encre) ; équipe : `content_status_badge` | élève : « Revoir » (`:to_review`), « Refaire » (`:score` sous 10/20), « Commencer » sinon ; enseignant et équipe : « Voir l'exercice » |
| `exercise_card_for_assignment(row, classroom_public_id:)` | classe de l'enseignant (`ClassroomOverviewQuery::AssignmentRow`) | le suivi si `counts`, sinon `nil` | `due_for_teacher` en `text-sm text-mute` + pastille « N en retard » (warning, dot) ou « N pas encore » | « Voir le suivi » si `counts` |

`meta` : « N questions » sur la page d'une leçon ; `nil` ailleurs. `type_label` : partout où la ligne porte `exercise_type`.

**Tokens** — couleurs : `bg-white`, `border-line`, `text-ink`, `text-mute`, `text-brand-strong`, `border-brand/40`, `shadow-card`, `hover:shadow-lift`, `text-success` (note ≥ 14/20) ; teinte de pastille : `subject_illustration(slug).tint`. Rayon : `rounded-card`. Typographie : titre `text-base` / 500 (pas de valeur arbitraire : la garde `design_tokens_test` les refuse), étiquettes `text-meta` (13 px), verbe `text-sm` / 500. Aucune couleur en dur ; l'ambre seulement via `due_badge` et « À revoir » / « en retard » (urgence).

**Comportement** — pas de Turbo Frame ni de Stimulus nouveaux. Les listes à « Voir plus » gardent `ui_reveal_item(index)` sur le `<li>` et `ui_reveal_more`. `prefers-reduced-motion` : la translation du survol vient de `transition`, coupée par la règle globale.

**États** — vide : les `ui_empty_state` existants de chaque section, inchangés. Chargement : rendu serveur, pas de squelette (aucun chargement différé nouveau). Erreur : aucune (lecture seule ; une source sans ligne donne l'état vide). Succès : la grille de cartes.

**Accessibilité** — la carte entière est la cible tactile (≥ 44 px) ; focus visible : contour 2 px `outline-brand` sur le pseudo-élément étiré du lien (toute la carte) quand il a le focus clavier ; la note garde son texte (la couleur n'est jamais seule porteuse) ; l'échéance a son icône.

### 3.2 Les branchements

- `classroom/student_classrooms/_assigned_exercise` et `_treated_exercise` : rendent `assessment/exercises/card` avec la carte du helper et `index` ; la liste de `student_classrooms/show` passe en grille.
- `catalog/courses/_exercise_row` : rend la carte (`exercise_card_for_lesson`) ; les bascules d'assignation passent dans le bloc. `_prepare_interros` : `material_slug` vient de `prepare.material_slug`.

### 3.2 bis — « Prépare interros » en une seule grille (amendement du 2026-10-30, demande du porteur sur capture)

Le titre de notion au-dessus de chaque carte répétait le titre de l'exercice, qui nomme déjà la notion. Il disparaît.

- Un seul `<ul id="prepare-interros-grid" class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">` pour tous les exercices de la leçon, dans l'ordre de la page : notions dans leur ordre, puis ceux de toute la leçon. 1 colonne au téléphone, 2 dès 640 px, 3 dès 1 280 px, 4 dès 1 536 px.
- Plus de `<h3>` de notion ni de « Toute la leçon » au-dessus des cartes. Le type de la carte (« Évaluation ») distingue les exercices de toute la leçon.
- Les ancres restent (UDR-0139 §3.7) : le `<li>` de la **première** carte d'une notion porte, en premier enfant, `<span id="notion-<slug>" class="block scroll-mt-24" tabindex="-1" aria-label="<nom de la notion>"></span>` ; celui de la première carte de toute la leçon, `<span id="toute-la-lecon" …>` de même. Le partial de carte reçoit ce repère par un local facultatif `anchor: { id:, label: }`.
- Les notions sans exercice gardent leur bloc (titre + « pas encore d'exercice »), sous la grille.

### 3.2 ter — « Prépare devoirs » pour les évaluations (amendement du 2026-10-30, demande du porteur)

La page d'une leçon (catalogue et page de leçon dans une classe) sépare les exercices par **type** :

- **« Prépare interros »** (`section#prepare-interros`) : les exercices de **fixation**, notions dans leur ordre puis ceux de toute la leçon. Intro : « Pour t'entraîner : un exercice par notion, puis sur toute la leçon. » Les notions sans exercice et l'état vide restent dans cette section.
- **« Prépare devoirs »** (`section#prepare-devoirs`, juste après) : les exercices d'**évaluation**, même ordre, même grille (`ul#prepare-devoirs-grid`, mêmes classes que §3.2 bis). Intro : « Pour te tester : des évaluations sur toute la leçon, comme un devoir. » La section n'est pas rendue quand la leçon n'a aucune évaluation.
- Le type sur la carte reste affiché (« Fixation », « Évaluation »).
- Ancres : chacune (`notion-<slug>`, `toute-la-lecon`) est posée **une seule fois**, sur la première carte qui la concerne dans l'ordre de la page (interros, puis devoirs).
- Les bascules d'assignation de l'enseignant restent sous chaque carte, dans les deux sections.
- `classroom/classrooms/_assigned_exercises` : chaque assignation rend la carte (`exercise_card_for_assignment`).

### 3.3 La carte de question — `assessment/exercises/show`

- `#exercise-sheet` devient une région sans cadre (`role="region"`, `aria-labelledby="sheet_title"`, `data-controller="math"`, `space-y-4`).
- L'énoncé, ses blocs et sa figure, s'il y en a, restent dans une `ui_card padding: :lg` (`id="exercise_statement_card"`).
- `ol#exercise_questions` : `list-none space-y-4` ; chaque `li#sheet-question-N.question` est une carte `rounded-card border border-line bg-white p-4 shadow-card sm:p-6`.
- En tête de la carte : `<div class="mb-3 flex items-center gap-2">` avec le numéro en pastille (`grid size-8 place-items-center rounded-full bg-brand-soft text-sm font-medium text-brand-strong tabular-nums`, `aria-hidden`) et le format (`text-meta text-mute`, `id="sheet-question-N-format"`). Le numéro reste lu : `<span class="sr-only">Question N, </span>` dans l'énoncé.
- Format, par `question_type` (`assessment.exercises.show.question_formats.*`) : `true_false` « Vrai ou faux » · `single_choice` « Une seule réponse » · `multiple_correct_2` et `multiple_correct_3` « Plusieurs réponses » · `fill_blank` « Texte à trous » · `numeric` « Réponse en nombre » · `ordering` « Remettre dans l'ordre » · `matching` « Relier » · `select` « Choix dans une liste » · `written` « Réponse rédigée » · `notebook` « Sur le cahier ».
- `sheet_kinds/_choice` ne répète plus « Plusieurs réponses » : le format le dit.
- Au téléphone, `#exercise-sheet` porte `data-bleed-keep` : les cartes de question restent dans la marge, arrondies (la règle `[data-bleed]` de l'UDR-0005 ne les met pas bord à bord).
- L'énoncé commence sans blanc de tête : le `sr-only` et le texte tiennent sur une ligne dans le `<p>` (`whitespace-pre-line` rendrait l'indentation).
- Image, solution et explication gardent leur rendu, dans la carte.

## 4. Conséquences

- Tout nouvel écran qui liste des exercices rend `assessment/exercises/card` via une méthode du helper ; il n'écrit pas sa ligne.
- Interdit désormais : une ligne d'exercice sans verbe d'action ; le nombre de bonnes propositions montré à l'élève.
- Les lignes de lecture de « Ma classe » et du suivi de classe portent `exercise_type` ; `PrepareInterrosQuery::Prepare` porte `material_slug`.
