# Journal — Leçons de 3ème en Histoire-Géographie, et leurs figures

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | `CONTROL_BOUND` passe de 1 000 à 3 000 (figure_kinds.rb) | Les bornes d'un curseur de frise sont des années (jusqu'à −3000..2100) : à 1 000, le curseur `start` du Lot A était refusé. | Non (constante, amende ADR §4.2) |
| 2026-10-30 | Garde de `figure.rb` écrite `defined?(…) \|\| require_relative(…)` | Même effet que `require_relative … unless defined?`, mais la branche `then` n'existe qu'hors Zeitwerk (valider.rb) et la couverture de branches de 100 % ne peut pas l'atteindre ; `\|\|` n'est pas une branche. Un test lance un sous-processus qui ne charge que figure_kinds et figure. | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `Coverage` ne garde que la dernière charge d'un fichier : un test qui recharge un fichier avec `load` détruit sa couverture.

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
