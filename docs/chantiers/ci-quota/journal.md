# Journal — La CI épuise le quota de minutes GitHub Actions

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

- **Où part le coût (2026-09-29, run [36409044736](https://github.com/Lnclassapp/App.Lnclassapp/actions/runs/36409044736), 14 jobs, 29 minutes facturées).** Travail utile (`bin/ci`) : 852 s. Plancher des 12 jobs de la matrice : 408 s, soit conteneur PostgreSQL 14 à 28 s (`Initialize containers`), Ruby et Node 10 à 15 s (`./.github/actions/setup`), checkout 1 à 2 s. Arrondi à la minute : + 8 minutes (21 min réelles → 29 facturées). Jobs `changes` et `ci` : 5 s chacun, 1 minute facturée chacun. Fichier et ligne qui portent le coût : `.github/workflows/ci.yml`, la matrice `tests.strategy.matrix.group` (10 jobs avec PostgreSQL) et les déclencheurs `on.push.branches` (45 % des runs).
- **L'API de facturation par run ne répond rien d'utile** : `GET /actions/runs/<id>/timing` renvoie `total_ms: 0` pour tous les runs de ce dépôt. Seuls les horodatages des jobs permettent de compter.

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
