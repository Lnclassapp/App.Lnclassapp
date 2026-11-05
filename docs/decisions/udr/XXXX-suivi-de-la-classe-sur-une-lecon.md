# UDR-XXXX : Suivi de la classe sur une leçon — lacunes, réussite par exercice, remédiation proposée
<!-- index
titre: Suivi de la classe sur une leçon
statut: Accepté
adr-lie: XXXX (lecture-de-la-classe-par-la-direction)
problematique: Où l'enseignant lit les lacunes et la réussite de sa classe, et où l'élève trouve l'exercice qui lève sa lacune, depuis que les pages de notion n'existent plus ?
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-05 |
| **Chantier** | `docs/chantiers/suivi-classe-lecon` |
| **ADR lié** | ADR-XXXX-lecture-de-la-classe-par-la-direction |
| **Remplacé par** | — |

---

## 1. Contexte

Les pages de notion ont disparu (#337). « Fiches à revoir » (page de la classe, UDR-0121) annonce « 3 élèves » mais ne mène à aucun détail ; l'enseignant ne voit plus la réussite par exercice ; l'élève avec une lacune ne sait pas quoi refaire. Les jours de séance ne sont plus modifiables, et l'équipe ne peut plus assigner depuis la leçon.

## 2. Décision

Pas de nouvelle page. Le détail vit là où le lien de « Fiches à revoir » mène déjà : sous la notion, dans la leçon vue depuis la classe. La réussite vit sous chaque exercice de la feuille vue depuis la classe, à côté de « Assigner ». La remédiation apparaît à trois endroits, toujours le même exercice, car l'élève peut arriver par chacun. Des liens ordinaires et des rendus serveur : aucun nouveau contrôleur Stimulus, aucun nouveau Turbo Frame.

## 3. Règles d'implémentation

### 3.1 Encadré « Dans votre classe » (leçon vue depuis la classe)

- **Où** : `catalog/revision_sheets/_sheet`, à la fin de la section de chaque notion (`id="notion-<slug>"`), seulement quand le local `class_gaps` (Hash `essential_slug → Detail`) est fourni et contient la notion avec au moins une ligne. Partiel `classroom/classroom_courses/_notion_gaps` (`locals: (detail:, essential_slug:)`).
- **Sur la page de la leçon de l'élève et hors classe**, `class_gaps` vaut `nil` : rien n'est rendu.
- **Coupe « Voir plus »** : l'encadré appartient à la notion ; si la notion est dans la partie repliée, l'encadré l'est aussi (même cible `rest`). Une ancre `#notion-<slug>` ouvre la fiche (comportement actuel de `openFromHash`).
- **Structure** : `<aside id="notion-gaps-<slug>" aria-labelledby="notion-gaps-<slug>-title" class="mt-4 rounded-card border border-line bg-white p-4 shadow-card font-sans">` ; `<h3 id="…-title" class="text-base font-medium text-ink">` « Dans votre classe » ; puis deux listes, chacune précédée d'un `<h4 class="mt-3 text-sm font-medium">` :
  - « À revoir (n) » : `<ul>` dont chaque `<li class="flex flex-wrap items-baseline justify-between gap-x-3 py-1 text-sm">` porte le nom (`text-ink`) et, en `text-mute`, « depuis le 3 nov. · 2 copies ratées » (`l(date, format: :short)`, pluriel par `count`). Ordre : de la plus ancienne à la plus récente.
  - « Lacune levée (n) » : même ligne, « levée le 4 nov. ». Ordre : de la plus récente à la plus ancienne.
  - Une liste vide n'est pas rendue (ni son titre).
- **Repli** : chaque liste montre 3 noms (`REVEAL_LIMIT` des helpers, UDR-0057 R3) puis `ui_reveal_more` (`ui_reveal_data` sur la liste, `ui_reveal_item(index)` sur chaque `li`).
- **Tokens** : `border-line`, `bg-white`, `text-ink`, `text-mute`, `rounded-card`, `shadow-card` seulement. L'encadré est hors de la feuille cahier : pas de jeton de `course_sheet.css`.

### 3.2 Réussite sous un exercice (feuille vue depuis la classe)

- **Où** : `catalog/courses/sheets/_teacher_bar`, avant la case « Choisir », quand le local `success` (`ClassSuccess` ou `nil`) est fourni. Rendu par l'enseignant, l'équipe et la direction (pour la direction, seule cette ligne est rendue : ni « Choisir » ni bascule, `can_assign` faux).
- **Texte** : `<p class="ps-success" id="sheet-success-<public_id>">` « 12 / 20 élèves ont réussi » (pluriel par `count`, 1 → « 1 / 1 élève a réussi ») ; sans copie : « Pas encore fait par la classe ». Jamais de pourcentage seul.
- **Tokens** : dans la feuille, `prepare_sheet.css` gagne `.ps-success { font-size: 14px; }` à côté de `.ps-status`, dans l'encre noire de la feuille (aucune couleur nouvelle) ; aucune couleur selon le taux.

### 3.3 Remédiation proposée (élève)

Une proposition = `{ essential_slug, course_slug, exercise_public_id | nil }`. Le lien est `course_sheet_path(course_slug, "notion-<essential_slug>", anchor: "sheet-exercise-<exercise_public_id>")` ; sans exercice, `course_path(course_slug, anchor: "notion-<essential_slug>")`.

- **« Ma classe » — `classroom/student_classrooms/_pending_gaps`** : la ligne garde sa structure ; seul son `href` change pour le lien ci-dessus. Le libellé reste le nom de la notion ; `aria-label` = « Refaire un exercice sur <notion> ».
- **Page de résultat — `assessment/session_results/_gap_outcome`** : quand la copie a ouvert ou laissé en attente une lacune et qu'une proposition existe, ajouter sous le message actuel `ui_button "Refais un exercice sur cette notion", href: <lien>, variant: :primary, icon_end: "arrow-right"`. Sans proposition d'exercice, rien de plus.
- **Page de la leçon — `catalog/revision_sheets/_sheet`** (local `proposals`, Hash `essential_slug → proposition`, `nil` hors élève) : en tête de la section de la notion, après son titre, `<p class="sheet-todo">` « À revoir : » suivi d'un lien « fais cet exercice ». Le paragraphe n'est jamais dans la partie repliée (la notion entière peut l'être : alors il l'est avec elle). `course_sheet.css` gagne `.sheet-todo` (encre de la feuille, soulignement du lien, pas de couleur nouvelle).

### 3.4 « Jours de séance » sur la page de la classe

- Rendre de nouveau `classroom/classrooms/_session_days` sur `classroom/classrooms/show`, juste après l'en-tête de la classe, pour l'enseignant de la classe seulement (pas l'équipe, pas la direction). Le partiel et ses textes existent (UDR-0077 §3.4) : on le rend tel quel.

### 3.5 Barre d'assignation de l'équipe

- `classroom/classroom_prepare_sheets/show` : pour l'équipe, `targets` contient la classe courante seule (la query fournit la cible) ; la barre est celle de l'enseignant (UDR-0149 §3). Hors de la classe (`/courses/…`), l'équipe ne voit toujours pas de barre.

### 3.6 « Fiches à revoir » chez la direction

- `school_admin/classrooms/show` rend `classroom/classrooms/_gaps` (même partiel, même ordre) ; chaque ligne mène à `classroom_course_path(…, anchor: "notion-<slug>")`.

### États obligatoires

| Surface | Vide | Chargement | Erreur | Succès |
|---|---|---|---|---|
| Encadré classe | pas d'encadré | rendu serveur, pas d'état | page d'erreur de l'application | §3.1 |
| Réussite | « Pas encore fait par la classe » | rendu serveur | idem | « n / N élèves ont réussi » |
| Remédiation | lien vers la notion (sans exercice) | rendu serveur | idem | lien vers l'exercice |

### Accessibilité

- Liens et boutons ≥ 48 px de haut (`min-h-tap`) ; focus visible `focus-visible:outline-2 focus-visible:outline-brand`.
- L'encadré est un `<aside>` nommé par son titre ; les deux listes ont un titre `h4` ; aucune information portée par la seule couleur.
- 390 px : les lignes passent à la ligne (`flex-wrap`), aucun défilement horizontal.

## 4. Conséquences

- La leçon vue depuis la classe devient l'écran de suivi d'une leçon ; toute future donnée de classe par notion s'y range, dans le même encadré.
- Interdit : afficher un taux de réussite en couleur selon sa valeur, ou un pourcentage sans le nombre d'élèves.
- Interdit : proposer à l'élève un exercice différent selon l'endroit.
