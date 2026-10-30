# Journal — Parcours matière → exercice

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | Lot A : le test de requêtes de `GET /courses` passe de 18 à 20 | la carte ajoute deux lectures au plus (UDR §4) à la vue d'une matière | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot A livré : query, carte, tests contrôleur et système au vert ; mesure du bench `mesure_parcours.js` après levier encore à faire (prd §7).

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Le contrôleur de la matière ne sert la carte que dans les blocs `if student` de `index` : `next_exercise_for` n'a donc pas de garde de rôle (sinon branche morte non couverte).

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
