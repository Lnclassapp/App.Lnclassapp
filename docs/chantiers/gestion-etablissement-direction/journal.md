# Journal — La direction gère son établissement

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-01 | Numéros ADR-0071 et UDR-0056 | ADR-0069 et 0070 sont pris sur des branches ouvertes (`perf/ci-quota`, `ccr-9b7287af-3kx7cj`) ; ADR-0065 à 0067 et UDR-0052, 0053 d'`espace-direction` sont en collision avec `Develop` | — |
| 2026-10-01 | Deux policies au lieu d'élargir `ManageSchoolPolicy` | Elle ouvre aussi l'import, les DRENA et la validation des comptes en attente (Q1) ; et l'équipe ne retire pas d'enseignant (grill 9) | ADR-0071 §4.1 |
| 2026-10-01 | Table `teacher_school_departures` | Sans trace du retrait, le code reprend l'enseignant aussitôt (grill 5) | ADR-0071 §4.4 |
| 2026-10-01 | Adaptateurs des nouvelles méthodes de port au Lot 0 | Leçon du challenge 1 d'`espace-direction` : `port_contracts_test` casse sinon | — |
| 2026-10-01 | Bloc « Classes par niveau » déplacé en partiel partagé au Lot 0 | La direction et l'équipe ont le même gabarit ; deux vues de l'équipe (`update`, `deactivate`) le rendaient aussi, trouvées par la recherche des appelants | UDR-0056 §3.2 |

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
