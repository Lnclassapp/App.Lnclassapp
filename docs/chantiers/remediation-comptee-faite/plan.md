# Plan d'exécution — Une remédiation compte comme exercice fait

> Cycle **bugfix**, un seul lot. Le plan n'est pas sauté : le lot porte une migration ([`bugfix.md` §3](../../workflows/bugfix.md#3-planifier--souvent-un-seul-lot)).
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 0 — correctif + index (séquentiel, seul)
```

Aucune donnée n'est corrompue (lecture fausse seulement, memo § Portée) : pas de lot de réparation.

---

## Lot 0 — « Rendu » inclut la remédiation, côté direction

- **Couche**       : infrastructure (queries CQRS, migration)
- **Fichiers**     : `app/infrastructure/queries/school/student_work_query.rb`
                     `app/infrastructure/queries/school/departed_students_query.rb`
                     `db/migrate/20261004190000_count_remediation_in_handed_in_index.rb` · `db/schema.rb` *(fichier partagé)*
                     `script/perf/measure_screens.rb` (écran « Anciens élèves » ajouté à la mesure)
- **Dépend de**    : —
- **Test associé** : `test/infrastructure/queries/school/student_work_query_test.rb`,
                     `test/infrastructure/queries/school/departed_students_query_test.rb`,
                     `test/controllers/school_admin/classrooms_controller_test.rb`
- **Done quand**   : le scénario du memo (X raté à 25 %, lacune, Y fait en remédiation à 80 %) montre Y rendu et le 80 % dans la
                     moyenne, sur « Travail des élèves », la page de la classe et « Anciens élèves » ; les écrans de la direction
                     ne régressent pas au volume de l'ADR-0067, sans parcours séquentiel de `exercise_sessions`.

---

## Reproduction rouge, puis vert

Tests écrits avant le correctif, lancés sur le code de `Develop` (`COVERAGE=0 PARALLEL_WORKERS=1`, les 4 fichiers des queries et des contrôleurs de la direction) : **46 runs, 5 échecs**, chacun pour la bonne raison (la remédiation est écartée). Après le correctif : 46 runs, 0 échec.

| Test | Rouge (avant) | Vert (après) |
|---|---|---|
| `StudentWorkQueryTest` « an exercise done in remediation is handed in… » (memo, 5 élèves) | taux et moyenne de classe `[50, 45]` | `[60, 51]` ; Aya 2 rendus, 53 % |
| `StudentWorkQueryTest` « a student whose only session on the assignment is a remediation… » | taux 0 | 100 |
| `StudentWorkQueryTest` DS-09 (réécrit : la remédiation à 100 de Moussa compte) | moyenne 70 | 85 |
| `DepartedStudentsQueryTest` « an exercise done in remediation in one of its classrooms… » | `[1, 25]` | `[2, 53]` |
| `SchoolAdmin::ClassroomsControllerTest` « an exercise done in remediation is handed in… » | aucune cellule « 100 % » (la classe affiche 50 %) | « 100 % », « 2 / 2 », « 53 % » |

Réécrit sans changer ce qu'il prouve : `DepartedStudentsQueryTest` « a student who left for another school… » — la remédiation rattachée à une assignation, qui devait ne pas compter, sort du test ; une remédiation **hors** assignation y reste et ne compte toujours pas.

---

## Mesures

### Protocole

- Copie `app_lnclassapp_perf_remediation` de `app_lnclassapp_perf_rapports_lot_c` (312 283 sessions ; l'originale n'est pas touchée).
- **Le jeu ne contenait aucune remédiation** (toutes les sessions `standard`, 86 944 lacunes en attente). Sur la copie, les **14 698** sessions terminées qu'ADR-0043 aurait ouvertes en remédiation le deviennent (`kind = 'remediation'`, `knowledge_gap_id` posé) : session démarrée après la fin de la session source d'une lacune en attente, même élève, même fiche. 1 551 d'entre elles tombent dans l'établissement mesuré (27 732 standard). Puis `VACUUM ANALYZE`.
- `RAILS_ENV=production … PERF_ONLY=admin_classroom,admin_teachers bin/rails runner script/perf/measure_screens.rb` : 3 de chauffe, 30 mesurées, 3 exécutions, médiane des 3 (ADR-0067). « Anciens élèves » (`PERF_ONLY=admin_departed`) : `PERF_RUNS=5`, une exécution, vu sa durée.
- Avant : code de `Develop`, ancien index. Après : code corrigé, copie migrée (`db:migrate`, 0,67 s pour la migration), `VACUUM ANALYZE`.
- Machine partagée (4 cœurs, charge ≈ 1) : l'écran témoin « Enseignants », que le chantier ne touche pas, bouge de +3 % en p50 et +13 % en p95 entre les deux séries.

### Écrans de la direction (médiane des 3 exécutions)

| Écran | p50 avant | p50 après | p95 avant | p95 après | Requêtes | Ko | Budget (p95 / Ko) |
|---|---|---|---|---|---|---|---|
| « Travail des élèves » `admin_classrooms` | 156,7 ms | 173,5 ms | 230,4 ms | 243,9 ms | 11 → 11 | 71,4 → 71,4 | **hors budget avant et après** (100 ms) |
| Page d'une classe `admin_classroom` | 35,3 ms | 32,7 ms | 52,8 ms | 57,5 ms | 9 → 9 | 42,5 → 42,5 | tenu |
| « Enseignants » `admin_teachers` *(témoin, non touché)* | 92,9 ms | 95,4 ms | 122,0 ms | 138,2 ms | 9 → 9 | 441,1 → 441,1 | **hors budget avant et après** (p95 et Ko) |
| « Anciens élèves » `admin_departed_students` | 8 737 ms | 8 903 ms | 9 158 ms | 9 276 ms | 7 → 7 | 18,4 → 18,4 | **hors budget avant et après** |

SQL de « Travail des élèves » (médiane des p50) : 100,9 → 114,4 ms. Le bruit de la machine couvre l'écart : pour l'isoler, A/B alterné de la seule requête des totaux sur la copie migrée, l'ancien index recréé pour l'occasion puis supprimé, 50 exécutions chacune :

| Requête des totaux (`totals_by`, 77 classes) | p50 | p95 |
|---|---|---|
| Ancienne : `kind = 'standard'`, ancien index | 74,3 ms | 95,1 ms |
| Nouvelle : tout `kind`, nouvel index | 76,3 ms | 104,3 ms |

Coût de la correction : **≈ 2 ms en p50** (+ 2,7 %), à la mesure des 5 % de lignes en plus. Taille de l'index : 14 Mo (ancien, gonflé par le jeu) → 11 Mo (reconstruit, 276 336 lignes).

### `EXPLAIN (ANALYZE, BUFFERS)` après la migration

- `StudentWorkQuery#classrooms` (`totals_by`, 77 classes) : `Index Only Scan using index_exercise_sessions_handed_in on exercise_sessions`, `Index Cond: (classroom_assignment_id = classroom_assignments.id)`, 754 boucles, 29 283 lignes, **Heap Fetches: 0**. Aucun `Seq Scan`. Le temps est dans l'agrégat et le tri des 22 792 lignes (élève × devoir), pas dans la lecture des sessions (≈ 9 ms).
- `StudentWorkQuery#classroom` (`totals_by`, une classe) : même *Index Only Scan*, 10 boucles ; 1,07 ms.
- `DepartedStudentsQuery#totals` (200 élèves de l'établissement : il n'a aucun ancien élève dans le jeu) : même *Index Only Scan*, `Filter: student_id = ANY (…)`, **Heap Fetches: 0** ; 6,4 ms.
- Avant la migration, les trois lisaient déjà l'ancien index de la même façon (83 à 140 ms selon la charge, 1,0 ms, 7,3 ms).

---

## Vérification de collision

Un seul lot : sans objet. `db/schema.rb` ne reçoit que la version et la ligne de l'index (le dump de PostgreSQL 16 réécrit toutes les contraintes `ANY (ARRAY[…])` : ces lignes sont écartées, comme dans `import-drenas` et `inscription-direction`).

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [ ] Bug reproduit **à la main** dans l'application avant toute ligne de code — *non fait : reproduit par un test de contrôleur sur la page réelle (voir journal)*
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test (memo § Reproduction, journal)
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause** (les deux queries CQRS), pas du symptôme
- [x] Test au vert · suite complète au vert
- [x] Cas symétrique vérifié : remédiation hors assignation, session commencée ou abandonnée, élève parti ou anonymisé, autre établissement ne comptent toujours pas (tests existants inchangés et verts)
- [x] Données déjà corrompues : aucune (lecture seule)
- [ ] Challenger a rejoué les étapes de reproduction dans l'application
- [x] Commit `fix(school): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés

## Vérifications (2026-10-04)

- `bin/rails test` : **3 617 runs, 0 échec, 0 erreur**, 8 sauts (tests `PERF=1` et assimilés) ; `coverage/.last_run.json` : **100 % lignes (11 342 / 11 342), 100 % branches (2 886 / 2 886)**.
- `bin/rubocop` : 1 335 fichiers, aucune offense. `bin/brakeman` : aucun avertissement.
- Tests système de la direction (`test/system/school_admin/`, `test/system/school/`, `test/system/finitions/school_admin_test.rb`) : **30 runs, 0 échec**.
- Migration jouée, annulée puis rejouée sur une base de développement migrée de zéro : l'index revient à sa définition exacte dans chaque sens.
