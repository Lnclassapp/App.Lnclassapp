# Journal — Refaire ou continuer depuis la correction

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-04 | Le local transmis aux partials s'appelle `redo_exercise:`, pas `redo:` (UDR §3 le nommait `redo:`). La valeur Stimulus et le paramètre d'adresse restent `redo`. | `redo` est un mot réservé de Ruby : `redo: nil` dans `locals:` donne une erreur de syntaxe du gabarit. | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le test système `Refaire` a d'abord buté sur deux liens « Refaire l'exercice » : l'encadré « Cette notion passe à revoir » de la correction (UDR-0120) en porte un second, vers l'ancien lecteur. Hors périmètre ; le test vise `#restart-exercise-link`.
- Le challenger a trouvé ce que les tests ne voyaient pas : l'exercice visé arrivait 92 px trop haut, sous la barre (les formules et figures changent la hauteur après le saut à l'ancre), et le second lien « Refaire l'exercice » (fiche « à revoir ») menait encore à la leçon. Corrigés : `scroll-margin-top`, `alignAnchor`, `href:` de `_gap_outcome`.
- Les revues ont trouvé une feuille « trouvée » qui ne contenait pas l'exercice (ancre périmée) et un lien de la fiche actif pendant la pause : la feuille ne compte désormais que si elle contient l'exercice.
- Le premier test d'alignement passait sans `alignAnchor` (aucune formule dans les données de test, et l'ancrage de défilement de Chrome compense une insertion) : il insère un bloc et coupe `overflow-anchor` pour devenir probant.
- `bin/rails test:system <fichier>` ignore le fichier et lance les 573 tests système ; `bin/rails test <fichier système>` lance le fichier seul.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Un exercice de la feuille d'un devoir (`StudentAssignedSheetsQuery`) n'a de `copy` qu'une fois rendu : `next_open` y lit donc « fait » = rendu, sans code propre au devoir.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Le test « Lire le sujet puis Précédent » ne devient pas rouge sans le retrait de `data-prepare-sheet-redo-value` (Turbo recharge la page, l'adresse ayant changé) | retrait gardé par précaution, test gardé comme garde-fou | — |
| L'arrêt de `alignAnchor` quand l'élève fait défiler n'est pas testé | coût d'un test système de plus | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-04 |
| **PR** | [#467](https://github.com/Lnclassapp/App.Lnclassapp/pull/467) vers `Develop` |
| **ADR produits** | — |
| **UDR produits** | UDR-0153 (amende UDR-0138 §3.4 et UDR-0151 §3) |
