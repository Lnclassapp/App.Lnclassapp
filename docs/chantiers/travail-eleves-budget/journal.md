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

| **2 — compter les élèves présents dans la requête des totaux (`LEFT JOIN`)** | 24,9 ms, mais une requête de 7,2 ms en moins | identique | **Oui (lot 2)** : p50 64,6 → 55,9 ms, SQL 34,4 → 28,3 ms dans la même série |

1a perdait encore 15 ms à agréger deux fois les 29 283 sessions, et lisait toute la table `classroom_students` (40 001 lignes) faute du filtre des classes.

Plan de la requête après les lots 1 et 2 (27,9 ms) : lecture d'index seule des sessions 6,6 ms, tri incrémental 8,5 ms, agrégat par (classe, élève) 4 ms, jointures aux 4 235 adhésions et `users` 7 ms.

## Leviers écartés

| Levier | Gain possible | Pourquoi écarté |
|---|---|---|
| Alléger la vue | ≈ 3 ms sur 12 | 77 lignes sans requête ni composant lourd : rien à retirer sans changer l'écran. |
| Construire la requête des totaux sans Arel | ≈ 7 ms (Ruby autour de 23 ms de SQL) | Gain faible pour un SQL écrit à la main dans une query qui en compose déjà. |
| Mettre l'aperçu en cache | tout le calcul | Le coût est dans une requête qu'on a corrigée ; un cache masque, il se décide par ADR, et la direction attend des chiffres frais après une échéance. |
| Dénormaliser les totaux par (classe, élève) | ≈ 20 ms de SQL | Une table tenue à jour à chaque session rendue, chaque départ et chaque anonymisation : un contrat nouveau (ADR), pour un écran dont le p50 est déjà à 62 ms. À rouvrir seulement si le challenger, sur une machine calme, mesure encore le p95 au-dessus de 100 ms. |

## Où part la queue du p95

60 rendus de l'écran, après les lots 1 et 2, avec le ramasse-miettes compté : médiane 54 ms. Les deux plus lents : 138 ms (SQL 39,6, vue 49,5, 0 GC) et 132 ms (SQL 32,3, vue 43,4, 1 GC mineur). Leur vue dure 3 à 4 fois sa médiane (12 ms) sans requête ni allocation de plus : le processeur virtuel ralentit tout le rendu. Le témoin non touché fait pareil (p95 ≈ 2 × p50).

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- Le profil d'un objet de requête lancé par `bin/rails runner` passe par le cache de requêtes (l'exécuteur l'active) : sans `ActiveRecord::Base.uncached`, chaque requête répétée dure 0 ms.
- L'estimateur de PostgreSQL se trompe sur la jointure sessions × adhésions (classe et élève corrélés) : il prévoit 1 ligne et choisit une boucle imbriquée. Réduire les lignes **avant** la jointure est plus sûr que d'espérer un autre plan.
- La valeur de 230 ms relevée par `ecrans-direction-lents` venait d'une machine chargée ; sur ce jeu, `Develop` mesure entre 143 et 163 ms en p95 le 2026-10-05.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| p95 de « Travail des élèves » sous 100 ms, prouvé | La queue vient de la machine de mesure ; le code a rendu ce qu'un calcul en direct peut rendre. | Si le challenger mesure encore > 100 ms sur une machine calme : dénormaliser les totaux, avec ADR |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | aucun |
| **UDR produits** | aucun |
