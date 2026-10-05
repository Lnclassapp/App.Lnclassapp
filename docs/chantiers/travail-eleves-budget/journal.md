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
| 2026-10-05 | Non-régression par comparaison complète, pas par échantillon : les 35 035 aperçus et pages de classe du jeu, avant et après. | Une requête d'agrégat réécrite se trompe sur les cas rares. Le jeu de l'ADR-0067 contient 61 407 devoirs rendus plusieurs fois, 14 698 remédiations et 357 élèves anonymisés présents, mais **aucune adhésion quittée** et un seul élève présent sans rendu (défaut D3 du challenger) : les départs sont prouvés par les tests de la query et par les scénarios du challenger, pas par la comparaison complète. | Non |
| 2026-10-05 | Merge de `Develop` (#167) : le levier 2 (élèves présents comptés dans la requête des totaux, `LEFT JOIN`) est abandonné ; le levier 1 reste. | `Develop` compte déjà, en une lecture (`present_counts`, `GROUPING SETS`), l'effectif de chaque classe et les élèves distincts de l'établissement dont l'accueil a besoin : la requête que le levier 2 retirait n'existe plus. Requêtes de l'écran : celles de `Develop`. | Non |

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

- **#167 (`accueil-direction`) a été fusionnée pendant le chantier** et modifie la même query : elle compte les élèves présents distincts de l'établissement par `GROUPING SETS` dans `present_counts`, la requête que le lot 2 supprimait. À la fusion de `Develop` (2026-10-05), **le lot 2 est retiré** ; le lot 1 s'applique tel quel sur la version de #167. Le lot 2, prouvé par le challenger sur l'ancienne base, n'est pas gardé « par principe » : un lot se rejoue mesuré sur la base qui l'accueille.
- **#173 a été fusionnée (12 h 27) pendant que je préparais la mesure finale.** Ma première « mesure finale » comparait donc `Develop`… qui contenait déjà le lot 1 : aucun écart, à juste titre. La mesure finale compare `f75011c7`, `Develop` juste avant la fusion. Le rapport du challenger et la correction de D3, poussés sur la branche après la fusion, entrent par la PR de clôture.
- **L'écran mesuré n'était plus le même.** Depuis #167, `/school-admin/classrooms` est l'accueil de la direction, gardé 5 minutes : mesuré au protocole, il lit le cache (28 ms, 9 requêtes) et ne dit rien de la query. Il se mesure cache vide (`PERF_COLD=1`), et la page d'un niveau, qui appelle la query en direct, entre dans `measure_screens.rb` (`admin_level`).
- **Mes tests ont tourné pendant la série B du challenger** (vers 11 h 59, 4 workers) : je résolvais le conflit avec #167. Ses chiffres de B restent dans la fourchette des autres séries, mais une mesure de phase 5 se protège : rien de lourd sur la machine tant que le challenger mesure.

## Ce qu'on a appris sur la codebase

- Le profil d'un objet de requête lancé par `bin/rails runner` passe par le cache de requêtes (l'exécuteur l'active) : sans `ActiveRecord::Base.uncached`, chaque requête répétée dure 0 ms.
- L'estimateur de PostgreSQL se trompe sur la jointure sessions × adhésions (classe et élève corrélés) : il prévoit 1 ligne et choisit une boucle imbriquée. Réduire les lignes **avant** la jointure est plus sûr que d'espérer un autre plan.
- La valeur de 230 ms relevée par `ecrans-direction-lents` venait d'une machine chargée ; sur ce jeu, `Develop` mesure entre 143 et 163 ms en p95 le 2026-10-05.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| p95 de « Travail des élèves » sous 100 ms, prouvé | La queue vient de la machine de mesure ; le code a rendu ce qu'un calcul en direct peut rendre. | Si le challenger mesure encore > 100 ms sur une machine calme : dénormaliser les totaux, avec ADR |

## Rapport du challenger

*2026-10-05, phase 5. Rôle distinct de l'auteur : il n'a écrit aucun code du chantier ; il a rejoué le bench sur sa propre copie de la base, avant de lire le memo. Mesuré sur la tête de la PR **avant** la fusion de #167 (lots 1 et 2), contre `Develop` `d65938c8`.*

**Verdict : le gain est reproduit ; aucun défaut de code ; trois écarts de documentation.**

| Affirmation | Verdict | Chiffres du challenger (12 exécutions de chaque côté, 4 séries alternées) |
|---|---|---|
| p50 −40 % | **retrouvé, mieux** | 97,8 → 53,8 ms (−45 %) |
| SQL p50 −56 % | **retrouvé** | 64,6 → 26,8 ms (−59 %) |
| Une requête de moins, −7 % d'allocations | **retrouvé** | 11 → 10 ; ≈ 19 350 → ≈ 18 065 |
| Requête des totaux 73,4 → 27,9 ms | **gain retrouvé** | 74,4 → 33,8 ms en médiane (28–38 annoncés au plan) |
| Chiffres identiques | **retrouvé** | 35 035 sorties octet pour octet, plus 9 scénarios piégés dans une transaction annulée (départs au seuil de 5 élèves, anonymisé, élève de deux classes, classe entièrement partie, sessions d'un autre établissement, remédiation seule, devoirs archivés) : 79 sorties identiques |
| Témoin inchangé | **retrouvé** | p50 20,7 → 20,4 ms |
| p95 non atteint (160 → 133 ms) | **133 ms non retrouvé** | 152,4 → **101,5 ms** (−33 %) ; 2 séries sur 4 sous 100 ms (93 ; 92), 2 au-dessus (108 ; 113) |
| La queue vient de la machine | **plausible** | p95/p50 du témoin ≈ 1,7, de l'écran ≈ 1,9 ; pointes de vue sans GC ; 150 mesures dans un processus : p95 **83,9 ms** |

- **D1, D2** (memo) : la phrase « une classe sans session rendue est absente des totaux » et le passage « `COUNT(DISTINCT)` → `COUNT(*)` » décrivaient le lot 1, pas le lot 2 (`LEFT JOIN`, `COUNT(handed.student_id)`). **Sans objet depuis le retrait du lot 2** : ils décrivent de nouveau le code.
- **D3** (journal) : le jeu n'a aucun départ ; corrigé dans « Décisions prises en cours de route ».
- **O1** : avec le lot 2, le plan lisait toute la table `users` (seq scan, 43 797 lignes, ≈ 5 ms), un coût qui suit la table entière et non l'établissement. Sans objet depuis le retrait du lot 2.

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-05 (fusion dans `Develop`) |
| **PR** | [#173](https://github.com/Lnclassapp/App.Lnclassapp/pull/173) ; clôture et mesure finale : PR de `docs/travail-eleves-budget-cloture` |
| **ADR produits** | aucun (réécriture locale d'une requête de lecture) |
| **UDR produits** | aucun |
| **Preuve** | Lot 1 : accueil cache vide p50 115 → 86 ms, SQL 75 → 47 ms ; page d'un niveau p50 60 → 53 ms, SQL 27 → 20 ms ; 38 485 sorties identiques ; challenger (lots 1 et 2, ancien écran) : p50 −45 %, SQL −59 %, 35 035 sorties et 9 scénarios piégés identiques ; 4 192 tests, couverture 100 % |
| **Chantiers de suivi** | p95 de la page d'un niveau (107 ms) et de l'accueil cache vide (142 ms) au-dessus de 100 ms : la queue vient surtout de la machine (témoin p95 ≈ 1,7 × p50) ; à rejouer sur une machine calme avant tout levier qui demanderait un ADR (dénormalisation) |
