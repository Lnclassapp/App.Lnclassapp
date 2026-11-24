# Journal — Accueil élève : « Inviter » et « Plus » dans la grille

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- …

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

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


## À trancher

- 2026-11-24 · Hauteur de la feuille « Plus » : 25 % au moins, jusqu'à la moitié puis défilement (option prudente appliquée dans l'UDR, réversible).
- 2026-11-24 · Pictogrammes des entrées : icônes du jeu existant sur pastille pastel, en attendant des illustrations (option prudente, réversible).
- 2026-11-24 · Lot A, ouverture de la feuille : le déclencheur doit être dans le périmètre du contrôleur `modal` (les cibles ne passent pas entre contrôleurs imbriqués). `ui_modal` gagne un paramètre additif `opener:` (HTML libre, sans effet pour les autres usages), et la feuille est rendue dans la case `li#student_more_cell` de la grille (une seule fois, mais par `_subjects`, pas par `show`). Réversible.
- 2026-11-24 · Lot A, hauteur : la `<dialog>` de `ui_modal` est déjà le panneau (25 dvh au moins, 90 dvh au plus) ; `min-h-sheet-quarter max-h-sheet-half overflow-y-auto` est porté par le corps de la feuille (la moitié de l'écran au plus pour la grille, puis défilement). Réversible.
- 2026-11-24 · Lot A, tests système (`test/system/classroom/student_home_more_test.rb`) écrits mais non exécutés : Chrome incompatible avec le `reset!` de Capybara dans cet environnement.
