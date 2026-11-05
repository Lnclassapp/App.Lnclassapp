# Journal — Calcul littéral préparé comme Thalès

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-05 | Deux figures fixes sans étiquettes (rectangle d'un étal, carré découpé) ; dimensions en $x$ dans les énoncés | Une étiquette `labels` de la figure géométrique affiche aussi la longueur calculée du segment (bande « AB = 7,0 ») qui contredirait une dimension littérale | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Les blancs d'un `fill_blank` s'écrivent `___` hors des `$…$` (règle `blank_marker`) ; l'unité d'une question numérique tient en 8 caractères au plus ; `-` et `−` comptent comme doublon dans `answers`.
- La CI a refusé le premier commit : le manifeste du jeu standard (`db/seeds/standard/jeu.yml`, clé `longue`) doit nommer le plus gros fichier v3 du dépôt, devenu Calcul littéral. `longue` passe à Calcul littéral ; Thalès sort du jeu standard (local, environnements de PR), Calcul littéral, complet avec ses sujets, y tient sa place.
- Puis l'empreinte de l'activité simulée du jeu standard (`test/db/seeds/standard_activity_test.rb`) a changé, puisque ses leçons ont changé : mise à jour sciemment (`4da42e1b74` → `41688b73c9`), comme le prévoit l'en-tête du test.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Les vérifications de calcul sont faites par un script sympy hors dépôt : 346 contrôles, 0 erreur restante.

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
