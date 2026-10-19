# Journal — [Titre du chantier]

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

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

## 2026-10-19 — Chantier abandonné

- Le porteur a vérifié sur le terrain : la 1ère compte les séries **A1, A2, C et D**. L'hypothèse du memo (1ère × A, C, D) est fausse.
- Le référentiel de développement (`db/seeds/catalog.rb`), la taxonomie des tests, les totaux (77 et 38 classes) et les ADR-0030 et ADR-0034 restent tels quels.
- Écart restant : le référentiel réel de Develop lie la 1ère à « A ». C'est une donnée saisie à l'écran par l'équipe, à corriger à l'écran, pas dans le code.
- La PR 236 est fermée sans fusion du code. Seuls le memo, le PRD, le plan et ce journal sont gardés, comme mémoire.
