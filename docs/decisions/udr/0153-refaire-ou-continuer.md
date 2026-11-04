# UDR-0153 : Depuis la correction, « Refaire l'exercice » et « Continuer les exercices » ramènent à la feuille
<!-- index
titre: Refaire ou continuer depuis la correction
statut: Accepté
adr-lie: —
problematique: Sur la correction d'une copie vérifiée depuis une feuille, « Refaire » ouvre l'ancien lecteur et « Retour à la leçon » ramène à l'exercice déjà fait.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/refaire-ou-continuer` |
| **ADR lié** | — (ADR-0121 pour les feuilles) |
| **Remplacé par** | — |

Amende l'UDR-0138 §3.4 (boutons de la correction) et l'UDR-0151 §3 (retour de la correction vers la feuille), pour une correction venue d'une feuille seulement.

---

## 1. Contexte

La correction est le seul écran qui sort l'élève de sa feuille. Le pilote veut qu'elle l'y ramène : pour refaire l'exercice, ou pour continuer les exercices qu'il n'a pas encore faits.

## 2. Décision

Correction venue d'une feuille (`@sheet` présent, l'élève est le propriétaire) : « Refaire l'exercice » rouvre la feuille à remplir avec l'exercice vide ; le second bouton rouvre la feuille à l'exercice suivant non fait, ou ramène aux cases quand tout est fait. Choix du pilote (2026-11-04) : « Continuer les exercices », « Reprendre le devoir » gardé pour un devoir, tout effacer au « Refaire », « Retour à la leçon » quand tout est fait.

## 3. Règles d'implémentation

**Données**
- `Queries::Catalog::PrepareSheetsQuery::Sheet` et `Queries::Classroom::StudentAssignedSheetsQuery::Sheet` gagnent `next_open(after:)` : parmi `exercises`, dans l'ordre, le premier exercice sans `copy` situé après celui dont le `public_id` vaut `after` ; sinon le premier sans `copy` de la feuille ; sinon `nil`. « Fait » = `copy` présent, réussi ou non (comme la progression de la case).
- `Assessment::SessionResultsController#load_result`, quand `@sheet` est présent : lit la feuille de l'élève, `PrepareSheetsQuery.new.call(course_slug: @result.course_slug, actor: current_actor).sheet(@sheet)` pour `return_to == "sheet"`, `StudentAssignedSheetsQuery.new.sheet(actor: current_actor, dom_id: @sheet)` pour `"class"` ; garde `@sheet_found` (booléen) et `@next_exercise` (`next_open(after: <exercice de la copie>)&.public_id`). Une erreur de lecture n'est pas avalée (pas de `rescue`).  La feuille ne compte comme trouvée (`@sheet_found`) que si elle contient l'exercice de la copie ; l'ancre d'une autre feuille ou d'un autre devoir donne le repli d'avant.

**Boutons de la correction** (`assessment/session_results/show`, à la place de la paire actuelle, même place, mêmes composants `ui_button`)
1. « Refaire l'exercice » (`assessment.exercises.show.redo`), mêmes conditions d'affichage qu'aujourd'hui (pas au sans-faute ; pendant la pause, `#restart_pause` à sa place ; `@can_restart`) :
   - feuille trouvée : un **lien** `ui_button … href:` (`variant: :brand, size: :lg, full: true, icon: "arrow-path"`, `id: "restart-exercise-link"`, `data: { turbo_prefetch: false }`) vers la feuille à remplir avec `redo: <public_id de l'exercice>` et `anchor: "sheet-exercise-<public_id>"` : `fill_course_sheet_path(course_slug, @sheet, redo:, anchor:)` ou `fill_student_assigned_sheet_path(@sheet, redo:, anchor:)` ;
   - sinon : le formulaire actuel (`#restart-exercise-form`, POST vers l'ancien lecteur), inchangé.
2. Second bouton (`variant: :secondary, size: :lg, full: true`), selon la feuille :

| Cas | Libellé | Lien |
|---|---|---|
| leçon, `@next_exercise` présent | « Continuer les exercices » (`.continue_exercises`) | `fill_course_sheet_path(course_slug, @sheet, anchor: "sheet-exercise-<next>")` |
| leçon, tout fait | « Retour à la leçon » (`.back_to_lesson`) | `course_path(course_slug, anchor: @sheet)` (la case de la feuille) |
| devoir, `@next_exercise` présent | « Reprendre le devoir » (`.back_to_assignment`) | `fill_student_assigned_sheet_path(@sheet, anchor: "sheet-exercise-<next>")` |
| devoir, tout fait | « Retour à Ma classe » (`.back_to_class`) | `student_classroom_path(anchor: @sheet)` |
| feuille introuvable | « Retour à la leçon » / « Retour à Ma classe » | `lesson_href` / `student_classroom_path` |
| pas de feuille (`@sheet` nil) | inchangé | inchangé |

**Feuille à remplir** (`catalog/prepare_sheets/fill`, `classroom/student_assigned_sheets/fill`)
- Le contrôleur lit `params[:redo]` : une chaîne égale au `public_id` d'un exercice de `@sheet`, sinon `nil` (`@redo`). Rien d'autre n'est lu.
- La feuille porte `data-prepare-sheet-redo-value="<public_id>"` quand `@redo` est présent (local `redo:` transmis par `_sheet` ; absent sinon).
- `prepare_sheet_controller.js` : valeur `redo` (String). À `connect`, après la restauration des brouillons, si l'exercice `[data-exercise-id="<redo>"]` existe : `this.blank(exercise)` (exactement le « Refaire l'exercice » de la feuille : champs vides, `data-checked="false"`, `{ redone: <copie> }` mémorisé, « Vérifier ma réponse » et « Indice » visibles), puis `history.replaceState` retire `redo` de l'adresse (l'ancre reste) et la valeur `redo` est retirée de l'élément, pour qu'un rechargement ou un retour arrière (cache Turbo) ne remette pas à blanc une nouvelle copie.
- Les autres exercices s'affichent comme aujourd'hui : un exercice vérifié montre les réponses de sa copie, son statut, « Voir ma correction » et « Refaire l'exercice ».

**Lien « Refaire l'exercice » de la fiche** (`assessment/session_results/_gap_outcome`, UDR-0120) : venu d'une feuille trouvée, il vise le même lien que le bouton « Refaire l'exercice » (local `href:`) ; sinon, la notion de la leçon (inchangé). Le lien ne reçoit `href:` que dans les conditions du bouton « Refaire l'exercice » (ni pendant la pause, ni si recommencer est interdit).

**Arrivée sur l'ancre** : `.ps-exercise` porte `scroll-margin-top: calc(var(--spacing-bar) + 0.75rem)` ; `prepare_sheet_controller.js#alignAnchor` ramène l'exercice de l'ancre en haut à chaque changement de hauteur de la feuille pendant 2 s (formules KaTeX et figures chargées après le saut), sauf si l'élève fait défiler (`wheel`, `touchstart`, `keydown`, `pointerdown`) ; une ancre malformée (`decodeURIComponent` en erreur) est ignorée. Ajout du 2026-11-04 (challenger) : sans cela, le titre « Exercice 2 » finissait 92 px sous la barre.

**Libellés** (`config/locales/assessment/session_results.fr.yml`) : `continue_exercises: "Continuer les exercices"` ; les autres existent.

**États**
- Succès : la table ci-dessus.
- Vide : feuille sans exercice non fait → ligne « tout fait ».
- Erreur : feuille introuvable → ligne « feuille introuvable » ; `redo` inconnu → ignoré.
- Chargement : liens serveur, aucun.

**Accessibilité** : des liens (`<a>`), pas des formulaires, pour « Refaire » et « Continuer » venus d'une feuille ; l'ancre amène le focus de lecture à l'exercice ; libellés explicites, aucun `aria-label` supplémentaire.

## 4. Conséquences

- L'élève reste dans sa feuille du début à la fin.
- La correction lit une feuille de plus (une requête de lecture) quand elle vient d'une feuille.
- Sans JavaScript, « Refaire » ouvre la feuille à l'exercice sans le vider : l'élève y trouve le bouton « Refaire » de la feuille.
