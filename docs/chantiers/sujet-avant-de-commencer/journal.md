# Journal — Chaque feuille dans une case, lue avant de commencer

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot A : la liste des fichiers du plan était trop courte. Des tests hors liste lisaient la feuille sur la page de la leçon ou de la classe (`assignments_controller_test`, `assignment_batches_controller_test`, `notion_anchors_test`, `classroom_essential_test`) ; les trois premiers ont été adaptés dans le lot, `classroom_courses_controller_test` et `classroom_essential_test` (page de la classe) restent au Lot B.
- Lot A : la base de test d'un worktree porte le nom du dossier (`app_lnclassapp_test_<worktree>`) ; elle n'existe pas à la création du worktree (`RAILS_ENV=test bin/rails db:create db:schema:load`).
- Lot A : `assignment_toggle_test` visitait la page de la leçon dans la classe ; en attendant le Lot B, il passe par la page de lecture du catalogue.

- Lot B : la liste des fichiers du plan était encore trop courte. Des tests hors liste lisaient la feuille dans « Ma classe » (`student_classrooms_controller_test`, `system/assessment/exercise_cards_test`, `system/classroom/student_classroom_test`) ou le retour « class » de la page de résultat (`sheet_checks_controller_test`) : adaptés dans le lot.
- Lot B : Capybara compare le texte rendu (`text-transform: uppercase` de `.ps-card-kind`, `.ps-title`) : « PRÉPARE DEVOIRS N°1 » dans les tests système, « Prépare devoirs n°1 » dans les tests de contrôleur.
- Lot B : un enseignant avec deux classes est renvoyé vers `/teachers` (choix de la classe enseignée) : dans un test de contrôleur, un enseignant par classe.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `.ps-page a { color: #000 }` écrase la couleur d'un lien : le bouton `.ps-start` est écrit `.ps-page .ps-start`.
- Le retour de la page de résultat dépend de `@owner` ; `sheet` n'est lu que pour `return_to=sheet` (le Lot B ajoutera `class` + `sheet`, `_exercise` poste déjà `sheet` dans les deux cas).
- Trois copies d'affilée sur un même exercice mettent la vérification en pause : un test qui poste plus de deux fois doit changer d'exercice.
- `catalog/prepare_sheets/_sheet.html.erb` (nouveau, hors liste) calcule les locals de `sheets/_sheet` pour la lecture et le remplissage ; le Lot B peut le rendre depuis la page de la classe.

- `StudentAssignedSheetsQuery::Sheet` porte maintenant `number` (rang parmi les feuilles de même nature), `position` et `total` ; `#sheet(actor:, dom_id:)` choisit le devoir parmi ceux de l'élève connecté, ce qui refuse d'office le devoir d'une autre classe.
- Le retour de la page de résultat accepte `sheet` pour `return_to=class` (page à remplir du devoir, ancre `sheet-exercise-<id>`) ; le libellé reste « Retour à Ma classe ».
- Le refus sans JavaScript de `SheetChecksController#back_to_lesson` redirige vers `fill_course_sheet_path(course, sheet)` : pour un devoir reçu (`sheet=devoir-…`) c'est une feuille inconnue du catalogue (message « n'existe plus » au lieu du refus). Fichier du Lot A, non touché ; à reprendre (retour `class` → page à remplir du devoir).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
