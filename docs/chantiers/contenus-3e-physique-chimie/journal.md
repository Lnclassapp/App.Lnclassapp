# Journal — Les 10 premières leçons de Physique-Chimie de 3ème

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | Lot P : avec `numbering: "numbers"`, les numéros suivent l'ordre du tableau `labels` (1, 2, 3…), pas celui des parties de la planche. Les 3 leçons à planche sont déjà écrites dans cet ordre. | Règle réelle de `plate.js` (index + 1) | Non |
| 2026-10-30 | Lot V (corrections après revues) : molécule bornée avant tout calcul (50 000 atomes refusés en moins de 0,5 s), clés d'un autre mode refusées (œil, alcane, dessin libre), curseur `carbons` entier, `bonds: []` accepté, liaison en double refusée (serveur et molecule.js). Dans figure_controller, le callback des modules ne fait que mémoriser le texte pendant un geste de curseur ; il écrit la zone live tout de suite hors curseur (poignées de géométrie). | Revues de sécurité et de tests de la PR | Non |

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
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
