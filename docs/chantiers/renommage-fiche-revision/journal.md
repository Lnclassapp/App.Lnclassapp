# Journal — « Fiche de cours » et « Fiche de révision » à l'écran

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-12 | Le chantier, ouvert pour « Fiche de révision », renomme aussi « Cours » en « Fiche de cours » | Décision du porteur au grill (question 6) | Non : UDR-0084 |
| 2026-10-12 | UDR numérotée 0084 | 0078 à 0083 déjà pris sur d'autres branches | — |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Lot 0 rouge refusé par le pre-commit** (2026-10-12) : le hook lance tout test stagé et refuse un rouge. Le plan voulait committer la garde rouge au Lot 0. Elle a été écrite et vue rouge (2 échecs, 62 clés listées), puis mise de côté et committée à l'intégration, une fois A, B et C mergés. Leçon : sur ce dépôt, un « test rouge du chantier » se prouve dans le journal, pas dans un commit. Les fichiers de traduction ne déclenchent aucun test au pre-commit.

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
