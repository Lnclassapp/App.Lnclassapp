# Journal — « Travail des élèves » de la direction sous son budget

## Où part le temps (2026-10-05, `Develop` `d65938c8`)

Sur 98 à 115 ms (p50), la requête des totaux (`StudentWorkQuery#totals_by`) en prend 56 à 85 : **une seule requête porte le coût**. Les autres : décompte des élèves présents 7 ms, devoirs par classe 0,7 ms, classes 1 ms. Vue 12 ms.

`EXPLAIN (ANALYZE, BUFFERS)` de la requête des totaux, établissement mesuré (77 classes, 754 devoirs, 4 235 élèves présents, 29 283 sessions rendues) : **73,4 ms**.

| Étape | Lignes | Temps |
|---|---|---|
| Lecture des sessions rendues (`index_exercise_sessions_handed_in`, lecture d'index seule) | 29 283 | 8 ms |
| Agrégat par (classe, devoir, élève) | 22 792 | 15 ms |
| Jointure aux adhésions présentes (hash) | 22 792 | 7 ms |
| **Boucle imbriquée sur `users` : 22 792 lectures d'index, 68 376 tampons** | 22 792 | **30 ms** |
| Tri pour `COUNT(DISTINCT handed.student_id)` puis agrégat par classe | 22 792 → 77 | 13 ms |

L'estimateur prévoit **1 ligne** à la sortie de la jointure aux adhésions (conditions corrélées classe et élève), d'où la boucle imbriquée sur `users`.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-05 | La valeur avant est celle du jour (156,9 ms p95), pas les 230 ms de `ecrans-direction-lents`. | Même code, même base : la machine était plus chargée le 2026-10-04. Chaque levier se compare à `Develop` rejoué dans la même série. | Non |
| 2026-10-05 | `COUNT(*)` remplace `COUNT(DISTINCT handed.student_id)`. | Une ligne `handed` par (classe, élève), et l'index unique `(classroom_id, student_id)` de `classroom_students` : une seule adhésion par élève et par classe. | Non |
| 2026-10-05 | Non-régression par comparaison complète, pas par échantillon : les 35 035 aperçus et pages de classe du jeu, avant et après. | Une requête d'agrégat réécrite se trompe sur les cas rares (deux sessions d'un devoir, remédiation, départ) ; le jeu de l'ADR-0067 les contient tous. | Non |

## Leviers essayés

| Levier | Requête des totaux | Résultat | Gardé ? |
|---|---|---|---|
| 1a — agréger par (classe, élève) en deux niveaux (devoir puis élève), sans le filtre des classes sur les adhésions | 43–62 ms (contre 75–104 ms dans la même série) | identique | Non : remplacé par 1b |
| **1b — agréger par (classe, élève) en un niveau, `COUNT(DISTINCT devoir)`, filtre des classes gardé** | **28–38 ms** (contre 68–95 ms dans la même série) | identique | **Oui (lot 1)** |

1a perdait encore 15 ms à agréger deux fois les 29 283 sessions, et lisait toute la table `classroom_students` (40 001 lignes) faute du filtre des classes.

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- Le profil d'un objet de requête lancé par `bin/rails runner` passe par le cache de requêtes (l'exécuteur l'active) : sans `ActiveRecord::Base.uncached`, chaque requête répétée dure 0 ms.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | aucun |
| **UDR produits** | aucun |
