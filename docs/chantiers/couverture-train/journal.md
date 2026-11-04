# Journal — Couverture du train #417

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-31 | `hints_controller.rb` : `&.questions` retiré | `SessionPlayQuery::Copy` porte toujours `questions` (une liste, jamais nil). Le `&.` sur la copie, atteignable (copie supprimée entre-temps), est gardé et testé. | Non |
| 2026-10-31 | `open_hint.rb` : `&.questions` retiré | `Exercise#questions` rend toujours une liste (`@questions || []`). Le `&.` sur l'exercice (introuvable), atteignable, est gardé et testé. | Non |
| 2026-10-31 | `assign_exercise_batch.rb` : `return created if created.failure?` retiré | Le port `create_batch` ne rend jamais d'échec (« Aucune autre erreur n'est rendue ») ; le repository rend toujours un succès, une panne lève. | Non |
| 2026-10-31 | `essential_repository.rb` : `sheet.is_a?(Hash) ? … : nil` devient `sheet["practice"]` | `essentials.sheet` est `NOT NULL` avec la contrainte `essentials_sheet_object` (jsonb de type objet) : toujours une table. | Non |
| 2026-10-31 | `check_practice.rb` : une liste à plusieurs cases jugeait des textes au lieu des identifiants (`blank_results(picked.map { by_id[it]&.content.to_s })`), donc toute bonne réponse était « à revoir ». Corrigé en `blank_results(picked)`, comme la copie (`SubmitExerciseCopy`) | Seule façon de couvrir `&.content` non nil : le test du bon verdict échouait. Seul changement de comportement du chantier, et c'est un bug ; le test `des listes à plusieurs cases` le garde | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-31 |
| **PR** | [#418](https://github.com/Lnclassapp/App.Lnclassapp/pull/418), fusionnée dans `Develop` le 2026-10-31 |
| **ADR produits** | aucun |
| **UDR produits** | aucun |
