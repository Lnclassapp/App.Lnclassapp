# Journal — Des images dans les fiches de cours

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

## 2026-10-10 — Lot 0

- **Clés étrangères en RESTRICT, pas CASCADE** : l'ADR proposait `on_delete: :cascade` ; `SchemaConstraintsTest` impose RESTRICT hors d'une liste fermée (ADR-0036). Corrigé dans la migration et l'ADR. Conséquence pour le Lot C : une question qui part doit d'abord perdre son image.
- **Adaptateurs et tâches de purge remontés au Lot 0** : `PortContractsTest` refuse un port sans adaptateur et `RecurringTasksTest` une tâche sans classe.
- **Une seule migration** au lieu de trois.
- **Environnement local** : 5 erreurs préexistantes, sans rapport avec le chantier (PostgreSQL 18 lève `RestrictViolation`, que Rails ne range pas en `InvalidForeignKey`). `npx` absent : `bin/rails test` sans chemin échoue au `css:build` ; les tests passent dossier par dossier.
