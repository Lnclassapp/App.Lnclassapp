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

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `.ps-page a { color: #000 }` écrase la couleur d'un lien : le bouton `.ps-start` est écrit `.ps-page .ps-start`.
- Le retour de la page de résultat dépend de `@owner` ; `sheet` n'est lu que pour `return_to=sheet` (le Lot B ajoutera `class` + `sheet`, `_exercise` poste déjà `sheet` dans les deux cas).
- Trois copies d'affilée sur un même exercice mettent la vérification en pause : un test qui poste plus de deux fois doit changer d'exercice.
- `catalog/prepare_sheets/_sheet.html.erb` (nouveau, hors liste) calcule les locals de `sheets/_sheet` pour la lecture et le remplissage ; le Lot B peut le rendre depuis la page de la classe.

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
