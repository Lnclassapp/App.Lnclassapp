# Journal — Refaire ou continuer depuis la correction

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-04 | Le local transmis aux partials s'appelle `redo_exercise:`, pas `redo:` (UDR §3 le nommait `redo:`). La valeur Stimulus et le paramètre d'adresse restent `redo`. | `redo` est un mot réservé de Ruby : `redo: nil` dans `locals:` donne une erreur de syntaxe du gabarit. | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le test système `Refaire` a d'abord buté sur deux liens « Refaire l'exercice » : l'encadré « Cette notion passe à revoir » de la correction (UDR-0120) en porte un second, vers l'ancien lecteur. Hors périmètre ; le test vise `#restart-exercise-link`.
- `bin/rails test:system <fichier>` ignore le fichier et lance les 573 tests système ; `bin/rails test <fichier système>` lance le fichier seul.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Un exercice de la feuille d'un devoir (`StudentAssignedSheetsQuery`) n'a de `copy` qu'une fois rendu : `next_open` y lit donc « fait » = rendu, sans code propre au devoir.

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
