# Memo — Écrans lourds : mesurer avant de mettre en cache

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | lots 1 à 4 livrés sur la branche (sans PR) ; lot 5 reporté après les lots UX |
| **Ouvert le** | 2026-09-29 |
| **Branche** | `perf/cache-ecrans-lourds` |

---

## Le problème

L'audit `finitions-ux` (§ 8 « Caching », branche `feature/finitions-ux`, 2026-09-29) constate qu'aucun écran n'est mis en cache : pas de fragment, pas de `Rails.cache.fetch`, pas de `fresh_when`. Solid Cache ne sert qu'à `rate_limit`. L'audit liste sept écrans « qui gagneraient le plus », sans chiffre. Le porteur tranche le 2026-09-29 : **« mesurer d'abord »**. Ce chantier ne met donc rien en cache. Il produit le chiffre avant, écran par écran, au volume de la feuille de route, et classe les leviers.

Une contrainte est déjà posée. L'[ADR-0062](../../decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md) a **écarté le cache** des indicateurs de pilotage (option B : chiffres périmés, clé difficile à tenir complète). Il fixe un **seuil de reprise à 300 ms** et impose un ordre : **d'abord** des index sur les dates, **ensuite seulement**, s'il le faut, un cache court. Pour la recherche, il prévoit un index trigramme.

## Pour qui

- **L'équipe** (Pilotage, Croissance, Établissements) : c'est là que la mesure dépasse le seuil.
- **La direction** (Travail des élèves) : la page dépasse 200 ms dès qu'un grand lycée est rempli.
- **Élèves et enseignants** : leurs écrans sont rapides côté serveur. Seul le catalogue pèse lourd en HTML.

## Pourquoi maintenant

- Le pilotage dépasse déjà le seuil de 300 ms de l'ADR-0062 au volume mesuré (40 000 élèves, 312 000 sessions). La production est encore loin de ce volume. Si l'adoption suit la feuille de route, elle l'atteindra dans l'année scolaire.
- La recherche dynamique (audit `finitions-ux`, point 6) enverrait une requête par frappe. Chaque recherche coûte déjà 260 ms.

## Mesure avant

**Machine** : conteneur de développement, 4 vCPU Intel Xeon à 2,1 GHz, 15 Go de mémoire, PostgreSQL 16.13 local, sans réseau entre Rails et la base.

**Code** : `origin/Develop` en `44125507`.

**Volume**, produit par [`script/perf/seed_dataset.rb`](../../../script/perf/seed_dataset.rb) :

- 504 établissements et **34 531 classes** de l'année ;
- 4 150 enseignants, dont 150 en attente ;
- **40 000 élèves**, dont 1 % d'anonymisés ;
- 211 cours (200 publiés), 1 261 fiches, 3 781 exercices, 18 902 questions ;
- 54 778 devoirs et **311 957 sessions** sur 60 jours, qui donnent 124 421 badges et 82 963 lacunes ;
- 1 200 parrainages et 6 000 partages.

L'établissement mesuré (« focus ») est un lycée public de 77 classes et **4 235 élèves** (55 par classe), avec sa direction et 60 enseignants.

**Méthode** : [`script/perf/measure_screens.rb`](../../../script/perf/measure_screens.rb). Le protocole complet est dans le [journal](journal.md#protocole).

- Rails tourne en **mode production** (eager load, gabarits compilés, Solid Cache) sur la base de développement.
- Chaque requête traverse toute la pile Rack.
- Par écran : 3 requêtes de chauffe, puis **30 requêtes mesurées**.
- Le bench est lancé **3 fois**. Le tableau retient la **médiane des 3 exécutions**.
- Les écarts entre exécutions restent sous 10 %, sauf pour `student_home` (24,3 à 31,6 ms).

Lecture des colonnes :

- **p50 / p95** : temps complet de la requête dans le processus.
- **SQL** et **Vue** : `db_runtime` et `view_runtime` de Rails, en p50.
- **Requêtes** : nombre de SELECT non servis par le cache de requêtes d'Active Record.
- **Même requête ×** : nombre de fois qu'une même forme de SQL revient dans un rendu. 1 signifie aucun N+1.
- **Ko gzip** : poids de la page après la compression de Thruster.

| Écran | Chemin | Rôle | p50 ms | p95 ms | SQL ms | Vue ms | Requêtes | Même requête × | Ko | Ko gzip |
|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|
| **Pilotage 7 j** | `/teams/dashboard` | Éq | **333** | **361** | 298 | 11 | 23 | 1 | 65 | 10 |
| **Pilotage année** | `/teams/dashboard?period=year` | Éq | **390** | **429** | 362 | 9 | 23 | 1 | 65 | 10 |
| Pilotage DRENA | `/teams/dashboard?drena=…` | Éq | 211 | 266 | 175 | 8 | 25 | 1 | 46 | 8 |
| **Recherche du pilotage** (frame) | `/teams/dashboard?q=kou` | Éq | **263** | **293** | 250 | 3 | 7 | 1 | 22 | 2 |
| **Travail des élèves** | `/school-admin/classrooms` | Dir | **214** | **240** | 195 | 9 | 10 | 1 | 64 | 6 |
| Établissements, page 1 | `/teams/schools` | Éq | 73 | 96 | 5 | **61** | 7 | 1 | **578** | 20 |
| Établissements, page 6 | `/teams/schools?page=6` | Éq | 76 | 87 | 8 | 60 | 7 | 1 | 578 | 20 |
| Établissements, recherche | `/teams/schools?search=bouake` | Éq | 35 | 47 | 8 | 24 | 7 | 1 | 208 | 12 |
| Catalogue (équipe, 210 cartes) | `/courses` | Éq | 70 | 80 | 5 | **58** | 8 | 1 | **550** | 16 |
| Catalogue (élève, 200 cartes) | `/courses` | É | 56 | 81 | 6 | 45 | 9 | 1 | 474 | 15 |
| Catalogue (enseignant) | `/courses` | Ens | 55 | 70 | 6 | 44 | 10 | 1 | 474 | 15 |
| Accueil enseignant | `/teachers` | Ens | 51 | 61 | 33 | 8 | 17 | 1 | 51 | 8 |
| Fiche établissement | `/teams/schools/:id` | Éq | 45 | 62 | 10 | 22 | 15 | 1 | 279 | 17 |
| Accueil équipe | `/teams` | Éq | 38 | 69 | 14 | 7 | 19 | 1 | 36 | 5 |
| Classe (enseignant) | `/classrooms/:id` | Ens | 35 | 46 | 7 | 20 | 15 | 1 | 159 | 12 |
| Croissance | `/teams/growth` | Éq | 30 | 35 | 16 | 6 | 8 | 1 | 28 | 5 |
| Accueil élève | `/students` | É | 25 | 36 | 8 | 9 | 14 | 1 | 58 | 8 |
| Mes classes (enseignant) | `/teachers/classrooms` | Ens | 25 | 33 | 4 | 16 | 10 | 1 | 81 | 7 |
| Exercice | `/exercises/:id` | É | 24 | 36 | 8 | 6 | 16 | 1 | 27 | 5 |
| Fiche essentielle | `/courses/:c/essentials/:e` | Ens | 20 | 25 | 5 | 7 | 13 | 1 | 24 | 5 |
| Enseignants (direction) | `/school-admin/teachers` | Dir | 18 | 25 | 6 | 7 | 8 | 1 | 74 | 6 |
| Cours dans la classe | `/classrooms/:id/courses/:c` | Ens | 17 | 24 | 5 | 7 | 14 | 1 | 27 | 5 |
| Page cours | `/courses/:slug` | Ens | 17 | 25 | 4 | 8 | 10 | 1 | 25 | 4 |
| Une classe (direction) | `/school-admin/classrooms/:id` | Dir | 17 | 23 | 6 | 6 | 9 | 1 | 30 | 4 |
| Ma classe (élève) | `/students/classroom` | É | 16 | 21 | 6 | 5 | 12 | 1 | 18 | 4 |
| Devoirs d'un cours | `/courses/:c/assignments` | Ens | 14 | 19 | 4 | 6 | 9 | 1 | 25 | 5 |
| Imports | `/teams/imports` | Éq | 10 | 16 | 3 | 4 | 5 | 1 | 20 | 4 |
| Activité récente de l'élève (frame) | `/students` | É | 7 | 9 | 2 | 1 | 4 | 1 | 9 | 1 |

Ce que le tableau dit :

1. **Aucun N+1 sur les 28 écrans.** Aucune forme de requête ne revient deux fois dans un même rendu, et chaque écran fait entre 4 et 25 requêtes. Les queries CQRS tiennent leur promesse d'un nombre fixe de requêtes.
2. **Quatre écrans concentrent le coût, et c'est du SQL.** Pilotage, recherche du pilotage et Travail des élèves passent 85 à 95 % de leur temps en base, contre 3 à 11 ms de rendu. **Un cache de fragment n'y gagnerait rien** : le coût est dans les agrégats.
3. **Deux listes coûtent au rendu, pas en base.** Établissements (61 ms de vue pour 50 lignes, 578 Ko de HTML) et catalogue (45 à 58 ms de vue, 474 à 550 Ko) passent moins de 6 ms en SQL. Ce sont les seuls écrans où un fragment ou un HTML plus léger paierait. Compressées, ces pages ne pèsent que 15 à 20 Ko : le coût porte donc sur le temps serveur et sur l'analyse du DOM par le téléphone, pas sur les données mobiles.
4. **Tous les autres écrans d'élève, d'enseignant et de direction restent sous 60 ms en p50.** Rien n'y justifie un cache.
5. Croissance (30 ms) et fiche établissement (45 ms), cités par l'audit, ne sont pas lourds à ce volume.

Le détail requête par requête, avec `EXPLAIN ANALYZE`, est dans le [journal, « Où part le temps »](journal.md#où-part-le-temps).

## Budget visé par écran

L'[ADR-0051](../../decisions/adr/0051-navigateurs-supportes-et-budget-de-poids.md) fixe un budget de **poids** pour le JavaScript (60 Ko gzip) et le CSS (30 Ko gzip). Il ne dit rien du temps serveur ni du HTML. Le seul budget de temps écrit est le **seuil de 300 ms du pilotage** (ADR-0062). Les cibles ci-dessous sont donc une **proposition à valider par le porteur** (question 1). Elles se mesurent en p95, au même volume et avec le même bench.

| Famille d'écrans | Cible p95 serveur | Écrans hors cible aujourd'hui (p95) |
|---|---|---|
| Pilotage de l'équipe (ADR-0062) | **< 300 ms**, sans cache si possible | Pilotage 7 j (361), Pilotage année (429) |
| Recherche (une requête par frappe si la recherche devient dynamique) | **< 100 ms** | Recherche du pilotage (293) |
| Écrans de direction | **< 100 ms** | Travail des élèves (240) |
| Listes de l'équipe (établissements, catalogue) | **< 100 ms** et **< 150 Ko de HTML brut** | Établissements (96 ms, 578 Ko), catalogue (80 ms, 550 Ko) |
| Écrans d'élève et d'enseignant | **< 100 ms** | aucun |

| Métrique | Contexte / volume | Valeur avant (médiane de 3) | Cible | Comment mesurée |
|---|---|---|---|---|
| p95 `/teams/dashboard` (7 j) | jeu `seed_dataset.rb` : 40 000 élèves, 312 000 sessions | 361 ms | < 300 ms | `measure_screens.rb`, 30 requêtes × 3 exécutions |
| p95 `/teams/dashboard?period=year` | idem (au 29 septembre, l'« année » couvre 28 jours) | 429 ms | < 300 ms | idem |
| p95 recherche du pilotage `q=kou` (5 693 comptes trouvés) | idem, 44 154 comptes | 293 ms | < 100 ms | idem |
| p95 `/school-admin/classrooms` | lycée de 77 classes, 4 235 élèves, 765 devoirs | 240 ms | < 100 ms | idem |
| Vue p50 et HTML de `/teams/schools` | 504 établissements, 50 par page | 61 ms, 578 Ko | < 25 ms, < 150 Ko | idem |
| Vue p50 et HTML de `/courses` (équipe) | 210 cours | 58 ms, 550 Ko | < 25 ms, < 150 Ko | idem |

## Mesure après (2026-09-29, lots 1 à 3)

Même machine, même jeu (`script/perf/seed_dataset.rb`, non resemé), même script, 30 requêtes × 3 exécutions, **médiane des 3**. Code : `perf/cache-ecrans-lourds` après fusion de `origin/Develop`. Chaque exécution a démarré avec une charge machine sous 1,5 : un autre agent jouait ses tests système, et une série prise sous charge (4 à 20) donnait jusqu'à +25 % (journal, « Ce qui a dérapé »). La mesure « avant » a été reprise sur le code fusionné, avant le premier levier : elle retrouve celle du cadrage à 5 % près (pilotage 7 j 338 ms, année 386, recherche 264, Travail des élèves 213 en p50).

Lecture pas à pas, sur les écrans visés (p50 / p95 ms, médiane de 3) :

| Écran | Avant | Lot 1 | Lot 2a (index) | Lot 2b (placements) | Lot 3 (trigrammes) | **Après (charge < 1,5)** | Budget p95 (ADR-0067) | Tenu ? |
|---|--:|--:|--:|--:|--:|--:|--:|:-:|
| Travail des élèves `/school-admin/classrooms` | 213 / 223 | 64 / 97 | — | — | — | **56 / 71** | < 100 | oui |
| Une classe (direction) | 15 / 20 | 19 / 33 | — | — | — | **16 / 24** | < 100 | oui |
| Pilotage 7 j | 338 / 402 | — | 257 / 304 | 190 / 240 | — | **199 / 220** | < 300 | oui |
| Pilotage année | 386 / 409 | — | 336 / 386 | 279 / 316 | — | **281 / 304** | < 300 | **non, à 1 %** |
| Pilotage DRENA | 203 / 221 | — | 179 / 201 | 139 / 163 | — | **150 / 189** | < 300 | oui |
| Recherche du pilotage « kou » (frame) | 264 / 295 | — | — | — | 53 / 89 | **38 / 47** | < 100 | oui |
| Établissements, recherche « bouake » | 38 / 58 | — | — | — | 50 / 119 *(sous charge)* | **37 / 46** | < 100 | oui |

Tableau complet après, 28 écrans (colonnes du tableau « avant ») :

| Écran | p50 ms | p95 ms | SQL ms | Vue ms | Requêtes | Ko | Ko gzip |
|---|--:|--:|--:|--:|--:|--:|--:|
| **Pilotage 7 j** | **199** | **220** | 161 | 12 | 21 | 65 | 10 |
| **Pilotage année** | **281** | **304** | 248 | 10 | 21 | 65 | 10 |
| Pilotage DRENA | 150 | 189 | 117 | 9 | 22 | 46 | 8 |
| **Recherche du pilotage** (frame) | **38** | **47** | 29 | 3 | 7 | 22 | 2 |
| **Travail des élèves** | **56** | **71** | 40 | 8 | 10 | 64 | 6 |
| Établissements, page 1 | 74 | 109 | 5 | 61 | 7 | **578** | 20 |
| Établissements, page 6 | 77 | 84 | 8 | 61 | 7 | **578** | 20 |
| Établissements, recherche | 37 | 46 | 8 | 25 | 7 | 208 | 12 |
| Catalogue (équipe, 210 cartes) | 68 | 78 | 5 | 57 | 8 | **550** | 16 |
| Catalogue (élève, 200 cartes) | 58 | 73 | 6 | 46 | 9 | **474** | 15 |
| Catalogue (enseignant) | 58 | 76 | 6 | 46 | 10 | **474** | 15 |
| Accueil enseignant | 55 | 62 | 34 | 8 | 17 | 51 | 8 |
| Fiche établissement | 46 | 60 | 10 | 24 | 15 | **279** | 17 |
| Accueil équipe | 40 | 69 | 15 | 8 | 19 | 36 | 5 |
| Classe (enseignant) | 38 | 49 | 8 | 20 | 15 | **159** | 12 |
| Croissance | 28 | 34 | 15 | 6 | 8 | 28 | 5 |
| Accueil élève | 25 | 35 | 8 | 9 | 14 | 58 | 8 |
| Mes classes (enseignant) | 26 | 32 | 5 | 16 | 10 | 81 | 7 |
| Exercice | 25 | 40 | 9 | 6 | 16 | 27 | 5 |
| Fiche essentielle | 21 | 29 | 6 | 8 | 13 | 24 | 5 |
| Enseignants (direction) | 17 | 25 | 6 | 7 | 8 | 74 | 6 |
| Cours dans la classe | 19 | 24 | 6 | 7 | 14 | 27 | 5 |
| Page cours | 18 | 25 | 5 | 8 | 10 | 25 | 4 |
| Une classe (direction) | 16 | 24 | 5 | 6 | 9 | 30 | 4 |
| Ma classe (élève) | 17 | 25 | 6 | 5 | 12 | 18 | 4 |
| Devoirs d'un cours | 15 | 21 | 4 | 7 | 9 | 25 | 5 |
| Imports | 11 | 15 | 3 | 5 | 5 | 20 | 4 |
| Activité récente de l'élève (frame) | 7 | 9 | 2 | 2 | 4 | 9 | 1 |

| Métrique | Contexte / volume | Avant | Cible | **Après** | Tenu ? |
|---|---|--:|--:|--:|:-:|
| p95 `/teams/dashboard` (7 j) | 40 000 élèves, 312 000 sessions | 361 ms | < 300 ms | **220 ms** | oui |
| p95 `/teams/dashboard?period=year` | idem (28 jours au 29 septembre) | 429 ms | < 300 ms | **304 ms** | **non** (p50 281 ms ; 298 à 313 selon l'exécution) |
| p95 recherche du pilotage `q=kou` | 44 154 comptes, 5 693 trouvés | 293 ms | < 100 ms | **47 ms** | oui |
| p95 `/school-admin/classrooms` | 77 classes, 4 235 élèves, 765 devoirs | 240 ms | < 100 ms | **71 ms** | oui |
| Vue p50 et HTML de `/teams/schools` | 504 établissements | 61 ms, 578 Ko | < 25 ms, < 150 Ko | 61 ms, 578 Ko | non : lot 5, reporté |
| Vue p50 et HTML de `/courses` (équipe) | 210 cours | 58 ms, 550 Ko | < 25 ms, < 150 Ko | 57 ms, 550 Ko | non : lot 5, reporté |

Ce que la mesure après dit :

1. **Travail des élèves** : ÷ 3,8 en p50 (213 → 56 ms), la requête des totaux ÷ 6,7 (195 → 29 ms). La réécriture seule en rapportait la moitié, l'index partiel l'autre.
2. **Pilotage 7 j** : 338 → 199 ms en p50, sous le seuil de l'ADR-0062. Les index de période ont payé 80 ms, la lecture unique des placements 65 ms, comme estimé au cadrage.
3. **Pilotage « année » : la piste ne tient pas tout son gain.** 386 → 281 ms en p50, mais **304 ms en p95**, à 1 % du budget. Le reste est proportionnel aux sessions de l'année (la moitié de la table au 29 septembre) : les index n'y servent plus, le planificateur lit en séquence. En mai, avec 9 mois de sessions, la page dépassera nettement 300 ms. Le levier suivant, selon l'ADR-0062, est un cache court à clé complète ou une table d'agrégats : il demande un ADR qui remplace l'option C, après une mesure avec un an de sessions (question 3).
4. **Recherche** : ÷ 7 (264 → 38 ms en p50), le SQL ÷ 8,7. Un terme de 2 caractères reste en parcours séquentiel (124 ms), comme avant.
5. **Établissements** : aucun gain au volume du jeu (504 établissements, 8 ms de SQL, le planificateur garde le parcours). Les index trigrammes paient au volume de la production (≈ 3 900 : 14 → 0,8 ms par requête, journal).
6. **Test `PERF=1` des budgets** (`test/performance/school/heavy_screens_budget_test.rb`, base de test, même jeu, 15 lectures après 3 de chauffe, charge < 2) : pilotage 7 j **261 ms**, pilotage année **368 ms — rouge**, recherche « kou » **34 ms**, Travail des élèves **62 ms**. L'environnement de test est plus lent que le bench (Bullet actif, journal SQL en `debug`, pas d'eager load) : il est pessimiste, et il dit la même chose que le bench — l'année est hors budget. **Il reste rouge volontairement** tant que le porteur n'a pas tranché le levier suivant. Les tests `PERF=1` d'import (écritures massives sur les tables nouvellement indexées) restent verts : exercices 37 s, fiches 29 s, cours 26 s, établissements 3 à 6 s, génération de classes 3 à 7 s.
7. **Aucun autre écran n'a bougé** au-delà du bruit (± 10 %) ; aucun N+1 ; le pilotage fait 21 requêtes au lieu de 23.

## Pistes classées (appliquées : 1 à 4 ; reportée : 5)

Classement du cadrage, conservé tel quel ; les chiffres réels sont dans « Mesure après ». Les pistes sont classées par ratio gain/risque, comme l'exige le [cycle optimisation](../../workflows/optimisation.md) : un lot = un levier = un chiffre. Les gains sont **estimés** à partir des plans `EXPLAIN ANALYZE` du journal, pas prouvés. Chaque lot les mesure avant d'être gardé.

| # | Levier | Écran | Nature | Gain estimé | Risque / décision |
|---|---|---|---|---|---|
| **1** | Index partiel `exercise_sessions (classroom_assignment_id, student_id) INCLUDE (score_percent) WHERE status = 'completed' AND kind = 'standard'`, et `totals_by` réécrit pour partir des devoirs de la classe | Travail des élèves | index + réécriture d'une query | **214 → ~30 ms**. Aujourd'hui, le plan parcourt les 42 000 couples classe × élève, puis fait 42 000 lectures d'index par élève (195 ms) au lieu de lire les sessions des 765 devoirs | Faible. Pas d'ADR (index local). Le résultat attendu est identique et un test de non-régression existe |
| **2** | Index trigramme `pg_trgm` (GIN) sur le nom normalisé des comptes, c'est-à-dire l'expression `translate(lower(...))` déjà utilisée, et le même index pour `schools` | Recherche du pilotage, recherche des établissements | index sur expression + extension | **263 → < 50 ms**. Aujourd'hui, deux parcours complets de `users` à 125 ms chacun, surtout passés en `translate()` ligne à ligne | Faible à moyen. `pg_trgm` est une extension standard de PostgreSQL, disponible en local ; sa disponibilité chez Railway reste à vérifier. L'ADR-0062 la prévoit, mais une extension est une dépendance : **amendement de l'ADR-0062** |
| **3** | Pilotage, premier temps : index sur `exercise_sessions.started_at`, sur `exercise_sessions (status, completed_at)`, sur `classroom_assignments.assigned_at` et sur `users.created_at`, dans l'ordre imposé par l'ADR-0062 | Pilotage | index | **333 → ~250 ms** en 7 jours : trois parcours complets de `exercise_sessions` (40 à 70 ms chacun) deviennent des lectures bornées. Le gain est plus faible sur « année », qui lit la moitié des sessions | Faible. Pas d'ADR : l'ADR-0062 l'a déjà décidé |
| **4** | Pilotage, second temps : une seule lecture des élèves placés, groupée par (niveau, DRENA), avec `COUNT(*) FILTER` pour les actifs. Elle remplace quatre jointures `classroom_students × users × classrooms × schools` de 30 à 100 ms chacune | Pilotage | réécriture de la query : mêmes définitions, moins de requêtes | **−100 à −150 ms** de plus. Les pistes 3 et 4 ensemble mènent à **~150 ms en 7 jours et ~200 ms sur l'année** | Moyen : les définitions de l'ADR-0062 doivent rester exactes. Chaque définition a déjà son test. Pas d'ADR si le résultat est identique |
| **5** | Listes lourdes au rendu. **Établissements** : une seule modale de confirmation partagée, au lieu de deux modales et deux formulaires par ligne, pour un écran strictement identique. **Catalogue** : cache de fragment par carte (`render collection, cached: true`, clé = `slug` et `updated_at` du cours, de sa matière et de son niveau) | Établissements, catalogue | HTML + fragment | Établissements : **578 → ~120 Ko, 61 → ~15 ms de vue**. Catalogue : **58 → ~15 ms de vue** avec un cache chaud | Moyen. Le fragment introduit un cache, donc un **ADR obligatoire** : clé, invalidation, et respect de l'ADR-0054 et de l'ADR-0028. Une carte ne contient aucune proposition correcte, elle est donc éligible. Paginer le catalogue changerait l'écran : c'est un chantier `feature`, pas celui-ci |

Leviers **écartés par la mesure**, et pourquoi :

- **Solid Cache sur le pilotage** (`Rails.cache.fetch`, clé période + DRENA + jour). Il ramènerait la page vers 30 ms, mais il réintroduit l'option B que l'ADR-0062 a refusée, alors que les pistes 3 et 4 devraient suffire à passer sous 300 ms. On n'y revient que si le bench après 3 et 4 reste au-dessus du seuil, et alors par un ADR qui remplace l'option C. C'est le dernier recours du cycle.
- **Cache HTTP / ETag** (`fresh_when`, `stale?`) sur la page cours, la fiche ou l'exercice. Ces pages coûtent 17 à 24 ms. Un 304 éviterait le rendu, mais ni l'authentification ni la query qui calcule l'ETag, soit un gain de quelques ms par page. Il faudrait en plus une clé qui inclut le rôle et l'acteur (ADR-0028). Pas rentable à ce volume.
- **Fragments sur les accueils** (élève, enseignant, équipe) : 25 à 51 ms, dont moins de 10 ms de vue. Le reste est du SQL qu'un fragment n'éviterait pas. De plus, l'UDR-0018 refuse un accueil périmé.
- **Pagination de l'index `schools` et index `LIKE` sur les établissements** : 504 lignes et 5 à 8 ms de SQL. Rien à gagner avant la recherche dynamique (piste 2).
- **Préchargement au survol de Turbo** (audit § 8) : il double les requêtes des pages survolées, mais seul le pilotage est assez coûteux pour que cela compte, et les pistes 3 et 4 règlent ce coût à la source. À réévaluer après ces pistes.

## Hors périmètre

- ~~Appliquer un levier~~ : le porteur a décidé le 2026-09-29 (après le cadrage) d'appliquer les pistes 1 à 4 dans ce chantier, **SQL et index seulement, aucune vue modifiée**. La piste 5 touche des vues : elle attend la fin des lots UX ([plan](plan.md), lot 5).
- Le poids du JavaScript et du CSS, déjà budgété et vérifié en CI (ADR-0051).
- La pagination ou les filtres par défaut du catalogue, et toute modification visible d'un écran : ce sont des chantiers `feature`.
- Les jobs (imports, génération de classes), qui ont déjà leurs tests de performance (`test/performance`, `PERF=1`).
- Le temps réseau et le rendu dans le navigateur : la mesure est faite côté serveur, sans réseau.
- L'historique du pilotage (table d'agrégats, option A de l'ADR-0062).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Mesurer en mode développement ? | Ce mode recharge le code, annote chaque gabarit et active Bullet et les logs de requêtes verbeux. Ses temps de vue sont gonflés et ne représentent pas la production. | Le bench tourne en `RAILS_ENV=production` sur la base de développement (voir le protocole du journal). |
| Le volume est-il réaliste ? | Il suit la feuille de route : 500 établissements, ≈ 35 000 classes (ADR-0039 §7), 200 cours complets (porte V1). Les 40 000 élèves dépassent le seuil de 20 000 à 30 000 estimé par l'ADR-0062. Ils sont concentrés dans 80 établissements adoptants, pas répartis un par classe. | Le tableau vaut « à ce volume ». Le coût du pilotage croît avec le nombre de sessions : à 1 million de sessions, il faudra remesurer. |
| Que couvre « année » au 29 septembre ? | L'année scolaire commence le 1ᵉʳ septembre : ici, « année » couvre 28 jours, comme « 30 j ». En mai, elle couvrira 9 mois de sessions. | La cible « année » devra aussi être vérifiée avec des sessions sur 9 mois (question 3). |
| Un cache résoudrait-il les écrans lents ? | Non. 85 à 95 % de leur temps est du SQL d'agrégats, et l'ADR-0062 a écarté le cache pour de bonnes raisons. | Les pistes 1 à 4 sont des index et des réécritures de requêtes. Le cache ne reste candidat que pour les deux listes où le rendu domine. |
| Y a-t-il des N+1 ? | Aucun : sur les 28 écrans, la forme de requête la plus répétée n'apparaît qu'une fois par rendu. | Pas de lot « N+1 ». |

## Cas limites identifiés

- Une recherche courte qui trouve beaucoup de comptes (« kou » trouve 13 % des comptes) restera chère même avec un index trigramme, parce que le `COUNT(*)` parcourt tous les résultats. Le bench mesure ce pire cas, pas une recherche sélective.
- La direction d'un collège de 28 classes coûte moins cher que celle du lycée mesuré. Le bench prend le plus gros établissement (4 235 élèves).
- Les temps sont mesurés sur une base locale, sans latence réseau. Sur Railway, chaque requête ajoute un aller-retour vers PostgreSQL : un écran de 20 requêtes et plus y perdra davantage qu'un écran de 7.

## Questions encore ouvertes

*Réponses du porteur du 2026-09-29 : 1. oui, budgets gravés dans l'[ADR-0067](../../decisions/adr/0067-budgets-de-temps-serveur-des-ecrans.md) ; 2. les deux, direction d'abord ; 4. oui, [amendement de l'ADR-0062](../../decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md#amendement-du-2026-09-29--index-lecture-groupée-des-placements-et-pg_trgm) ; 5. après les lots UX, avec son ADR. La question 3 reste ouverte, et elle compte maintenant (voir « Mesure après »).*

1. **Budgets** : les cibles p95 proposées (300 ms pour le pilotage, 100 ms ailleurs, 150 Ko de HTML brut) conviennent-elles ? Faut-il les graver dans un ADR, à côté du budget de poids de l'ADR-0051 ?
2. **Ordre des lots** : commencer par la direction (piste 1 : gain ÷ 7, risque faible) ou par le pilotage (pistes 3 et 4, pour repasser sous le seuil de l'ADR-0062) ?
3. **Volume de référence** : faut-il aussi faire tourner le bench avec des sessions étalées sur une année complète (≈ 1,5 million de sessions), pour valider la période « année » en fin d'année scolaire ?
4. **`pg_trgm`** : d'accord pour activer l'extension en production (Railway), par un amendement de l'ADR-0062 ?
5. **Cache de fragment du catalogue** (piste 5) : ADR maintenant, ou attendre que le catalogue dépasse 200 cours ?
