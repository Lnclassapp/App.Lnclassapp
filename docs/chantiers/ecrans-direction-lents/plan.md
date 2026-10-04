# Plan d'exécution — Écrans de la direction dans leur budget

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Cycle : [optimisation](../../workflows/optimisation.md) : **un lot = un levier = un chiffre**. Ordre des leviers ([ADR-0062](../../decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md), [ADR-0067](../../decisions/adr/0067-budgets-de-temps-serveur-des-ecrans.md)) : index, puis requête, puis cache par ADR.

## Graphe

```
Lot 0 — Jeu représentatif (sur la copie de mesure) + bench « avant »      ✅
  ↓
Lot 1a — « Anciens élèves » : index classroom_students (student_id)       ↩️ joué, puis annulé (inutile après 1b)
  ↓
Lot 1b — « Anciens élèves » : liste lue dans les adhésions de l'établissement   ✅ gardé
  ⋯
Lot 2 — « Travail des élèves » : agrégat élève × devoir                   à jouer
Lot 3 — « Enseignants » : poids du HTML (441 → 152,5 Ko)                 leviers 1 et 3b ✅ · 150 Ko non atteint
Lot D — script/perf/dataset.rb : semer anciens élèves et remédiations     dette, lot à part
```

Lots 1a et 1b : séquentiels (même écran, même base de mesure). Lots 2 et 3 : indépendants par les fichiers ; ils restent à jouer.

Contrat d'exécution de chaque lot (cycle optimisation, étape 4) :

1. le bench reproductible produit la valeur *avant* (`script/perf/measure_screens.rb`, `PERF_ONLY=…`) ;
2. les tests de non-régression sont **verts avant** le levier ;
3. **un seul levier**, puis le bench relancé (3 exécutions, médiane), chiffre noté ici ;
4. un gain nul ou marginal annule le pas, et le journal dit pourquoi.

---

## Protocole

- **Base** : `app_lnclassapp_perf_direction`, copie de `app_lnclassapp_perf_rapports_lot_c` (jeu de l'ADR-0067 : 500 établissements, 40 000 élèves, 312 283 sessions). L'originale n'est pas touchée :
  `PGPASSWORD=dev-rails createdb -U dev-rails -h localhost -T app_lnclassapp_perf_rapports_lot_c app_lnclassapp_perf_direction`
- **Le jeu n'avait aucun ancien élève** dans l'établissement mesuré (« Lycée moderne de Daloa 1 », 77 classes, 4 235 élèves, tous présents) : la page ne mesurait que la recherche d'une liste vide. Sur la copie seulement, **303 élèves (7,2 %) quittent l'établissement**, une heure après leur dernière session (aucune session n'est postérieure au départ). Parmi eux, **152 rejoignent une classe d'un autre établissement**. Le geste est celui de `JoinAsStudent` : `leave_primary` pose `left_at` et garde `primary`, puis `add_primary` crée une adhésion principale ailleurs. « Parti » suit la définition de `DepartedStudentsQuery` : un élève passé par une classe de l'établissement, sans adhésion présente, c'est-à-dire non quittée, d'une classe active de l'année. Les 2 360 sessions de ces élèves restent dans les classes de l'établissement. La liste compte donc 303 lignes, plafonnées à 200 (`truncated`). La requête, jouée par `psql -v ON_ERROR_STOP=1 -f`, puis `VACUUM ANALYZE` :

```sql
BEGIN;
CREATE TEMP TABLE departing ON COMMIT DROP AS
SELECT cs.id AS membership_id, cs.student_id,
       LEAST(GREATEST(cs.joined_at, MAX(es.started_at), MAX(es.completed_at)) + interval '1 hour',
             now()::timestamp - interval '1 hour') AS left_at
  FROM classroom_students cs
  JOIN classrooms c ON c.id = cs.classroom_id
  JOIN school_staffs ss ON ss.school_id = c.school_id
  JOIN users admin ON admin.id = ss.user_id AND admin.contact = '0720000001'
  LEFT JOIN exercise_sessions es ON es.student_id = cs.student_id
 WHERE cs.left_at IS NULL AND cs.student_id % 14 = 0
 GROUP BY cs.id;

UPDATE classroom_students cs SET left_at = d.left_at FROM departing d WHERE cs.id = d.membership_id;

WITH targets AS (
  SELECT c.id, row_number() OVER (ORDER BY c.id) - 1 AS rank, count(*) OVER () AS total
    FROM classrooms c
   WHERE c.status = 'active' AND c.school_id <> (SELECT school_id FROM school_staffs ss JOIN users u ON u.id = ss.user_id WHERE u.contact = '0720000001')
     AND EXISTS (SELECT 1 FROM classroom_students x WHERE x.classroom_id = c.id)
)
INSERT INTO classroom_students (classroom_id, student_id, "primary", joined_at)
SELECT t.id, d.student_id, true, d.left_at
  FROM departing d JOIN targets t ON t.rank = d.student_id % t.total
 WHERE d.student_id % 28 = 0;
COMMIT;
VACUUM ANALYZE classroom_students;
```

  Résultat attendu : `SELECT 303`, `UPDATE 303`, `INSERT 0 152`. `script/perf/dataset.rb` n'est **pas** modifié (lot D, dette).
- **Mesure** : la commande de l'en-tête de `script/perf/measure_screens.rb`, avec `DATABASE_URL=postgres://dev-rails:dev-rails@localhost:5432/app_lnclassapp_perf_direction PERF_ONLY=admin_departed_students`. L'écran y est ajouté par ce chantier, sur la même ligne que dans `remediation-comptee-faite` (#169). Protocole de l'ADR-0067 : 3 chauffes, 30 mesures, 3 exécutions, médiane des 3. **Avant** : 10 mesures par exécution (`PERF_RUNS=10`), car chaque requête durait 8 s.
- **Témoins** : « Travail des élèves », la page d'une classe et « Enseignants » (`PERF_ONLY=admin_classroom,admin_teachers,admin_departed`) ne sont pas touchés. Leurs chiffres retrouvent ceux de #169 (35,3 → 33,9 ms p50 ; 52,8 → 55,5 ms p95 pour la page d'une classe) : la machine est comparable.
- **Machine** : partagée, 4 cœurs, charge ≈ 0,5 à 0,9 pendant les séries. Ruby 3.4 avec YJIT, PostgreSQL 16.

## Lot 0 — Jeu représentatif et bench « avant »

- **Couche**       : mesure (aucun code applicatif)
- **Fichiers**     : `script/perf/measure_screens.rb` (écran `admin_departed_students`)
                     `test/infrastructure/queries/school/departed_students_query_test.rb` *(caractérisation)*
                     `test/controllers/school_admin/departed_students_controller_test.rb` *(caractérisation)*
- **Dépend de**    : —
- **Test associé** : les deux fichiers ci-dessus, **verts avant** tout levier (15 runs). Ils couvrent la dernière classe (rejointe en dernier, la plus haute à égalité, quoi qu'il se soit passé ailleurs ensuite) et la présence (non quittée, classe active de l'année, principale ou non : une classe archivée de l'année ou active d'une année passée ne rend pas présent). Ils couvrent aussi l'ordre dans une année (nom, prénom, compte), la recherche au-delà du plafond, la liste exactement au plafond, un devoir rendu deux fois, et, sur la page, le compte, l'ordre et le « — ». Les cas existants (départ vers un autre établissement, compte anonymisé, élève présent, élève jamais venu) restent tels quels.
- **Done quand**   : ✅ la page affiche 200 anciens élèves sur 303 et le bench donne la valeur *avant*.

| « Anciens élèves » *avant* | Exécution 1 | 2 | 3 | **Médiane** |
|---|---|---|---|---|
| p50 | 8 367,5 ms | 8 189,0 ms | 8 276,1 ms | **8 276,1 ms** |
| p95 | 8 602,0 ms | 8 860,5 ms | 8 821,2 ms | **8 821,2 ms** |
| SQL (p50) | | | | 8 175,2 ms |
| Requêtes · HTML | | | | 8 · 110,4 Ko |

`EXPLAIN (ANALYZE, BUFFERS)` *avant*, requête de la liste : **17 454 ms**, dont 413 ms de compilation JIT (coût estimé 24 millions).
- `Nested Loop Anti Join` (13 251 ms) : `Seq Scan on users` (39 644 élèves), puis, pour chacun, un `Materialize` des 3 932 adhésions présentes de l'établissement. **148 147 930 lignes écartées par le `Join Filter`** : aucun index de `classroom_students` ne commence par `student_id`. Le seul qui en part est l'index unique partiel des adhésions principales actives.
- `JOIN LATERAL` de la dernière classe, exécuté **35 712 fois** (une fois par élève non présent du pays) : 77 `Index Scan` des classes de l'établissement à chaque boucle (2 749 824 sondes au total), pour 303 lignes trouvées.
- Les totaux (*Index Only Scan* de `index_exercise_sessions_handed_in`, 754 boucles, 0 *Heap Fetch*) : **6,2 ms**. Le nom de l'établissement : 0,04 ms.

## Lot 1a — Index `classroom_students (student_id)` ↩️ annulé

- **Couche**       : infrastructure (migration seule)
- **Fichiers**     : aucun livré. L'index a été créé sur la copie (`CREATE INDEX CONCURRENTLY index_classroom_students_on_student_id ON classroom_students (student_id)`), mesuré, puis supprimé. Aucune migration n'a été écrite, et `db/schema.rb` n'a pas changé.
- **Dépend de**    : Lot 0
- **Test associé** : tests du Lot 0 (inchangés).
- **Done quand**   : p95 < 100 ms. **Non atteint** : 725 ms. L'index ne sert plus après le Lot 1b, il est donc annulé.

| « Anciens élèves » | p50 | p95 | SQL p50 | Requêtes · Ko |
|---|---|---|---|---|
| Avant (Lot 0) | 8 276,1 ms | 8 821,2 ms | 8 175,2 ms | 8 · 110,4 |
| Index seul (30 × 3, médiane) | 618,0 ms | **725,4 ms** | 554,3 ms | 8 · 110,4 |

`EXPLAIN` avec l'index : 552 ms, dont **358 ms de JIT** (coût estimé encore à 695 000). L'anti-jointure devient un `Merge Anti Join` (47 ms). Le `LATERAL` reste exécuté 35 712 fois, mais par l'index (`Index Cond: student_id = users.id`, 107 280 tampons). Le levier divise le temps par 12, mais la requête part toujours de tous les élèves du pays.

**Annulation, mesurée** : après le Lot 1b, le plan ne lit plus `classroom_students` par élève. Le bench A/B, 30 × 3 avec la réécriture, donne un SQL p50 de 24,0 ms avec l'index et de 26,0 ms sans : l'écart est dans le bruit, et l'`EXPLAIN` n'utilise pas l'index. Le garder ferait payer un index de plus à chaque inscription et à chaque départ, sans rien gagner.

## Lot 1b — Liste lue dans les adhésions de l'établissement ✅ gardé

- **Couche**       : infrastructure
- **Fichiers**     : `app/infrastructure/queries/school/departed_students_query.rb` (`PASSED` remplace `LAST_CLASSROOM` et `NOT_PRESENT` ; `COLUMNS` ; `#departed`)
- **Dépend de**    : Lot 0
- **Test associé** : tests du Lot 0, verts avant et après. Une comparaison ancienne/nouvelle requête a été faite sur la copie de mesure : 5 établissements, dont celui de 303 anciens élèves, 4 recherches et 2 plafonds, soit 40 cas, tous identiques.
- **Done quand**   : p95 < 100 ms, mêmes lignes affichées. **SQL : atteint.** Page : **p50 dans le budget, p95 non atteint** (136 ms), voir « Où part le temps restant ».

Le levier : la requête ne part plus de tous les comptes élèves (≈ 40 000), mais des seules adhésions de l'établissement (4 235 lignes), lues une fois et groupées par élève. `array_agg(classroom_id ORDER BY joined_at DESC, id DESC)[1]` donne la dernière classe, et `HAVING NOT bool_or(left_at IS NULL AND status = 'active' AND school_year = :année)` qu'aucune adhésion n'est présente. Les comptes (rôle, anonymisation), la classe et le niveau ne sont joints que pour ces élèves. Définitions, ordre, plafond et recherche sont inchangés. La requête des totaux n'est pas touchée.

| « Anciens élèves » (30 × 3, médiane) | p50 | p95 | SQL p50 | Vue p50 | Requêtes · Ko |
|---|---|---|---|---|---|
| Avant (Lot 0) | 8 276,1 ms | 8 821,2 ms | 8 175,2 ms | 34,4 ms | 8 · 110,4 |
| Réécriture, index 1a présent | 65,6 ms | 147,6 ms | 24,0 ms | 23,2 ms | 8 · 110,4 |
| Réécriture, sans index (série A/B) | 80,8 ms | 135,6 ms | 26,0 ms | 28,9 ms | 8 · 110,4 |
| **Après** : réécriture seule, avec les témoins | **57,7 ms** | **136,1 ms** | **23,7 ms** | 19,0 ms | **8 · 110,4** |

Exécutions de la série *après* : p50 57,7 / 59,6 / 53,4 ms ; p95 136,1 / 182,5 / 134,4 ms. Les trois témoins de la même série : « Travail des élèves » 148,8 / 229,0 ms, la page d'une classe 33,9 / 55,5 ms, « Enseignants » 91,2 / 121,8 ms (p50 / p95), au niveau de #169.

`EXPLAIN (ANALYZE, BUFFERS)` *après* :
- liste : **13,0 ms** (au lieu de 17 454 ms). `Hash Join` des 77 classes de l'établissement sur un `Seq Scan` de `classroom_students` (40 153 lignes, 2,5 ms), `Sort` des 4 235 adhésions, puis `GroupAggregate` : 303 élèves gardés, 3 932 présents écartés. Ensuite 303 `Index Scan` de `users_pkey`, puis des classes et des niveaux. Pas de JIT (coût 1 526). Hors `EXPLAIN`, 30 exécutions : **p50 9,8 ms**, p95 10,2 ms ;
- totaux : **7,0 ms** (inchangés), 5,4 ms pour une recherche (« kon », 39 lignes) ;
- établissement sans ancien élève : 6,5 ms (aucun élève), 7,7 ms (établissement le plus peuplé après celui de la mesure).

**Variantes écartées** (exécution serveur, 40 fois, p50) : la forme gardée fait **9,84 ms**. `DISTINCT ON` avec un `bool_or` en fenêtre fait 11,13 ms. `DISTINCT ON` avec le `NOT EXISTS` d'origine fait 19,13 ms, et reste exposé à une anti-jointure en boucle imbriquée si l'estimation se trompe, comme avant. Forcer une boucle imbriquée sur l'index `(classroom_id, student_id)` gagnerait environ 4 ms, mais seulement en touchant aux réglages du planificateur (`random_page_cost`) : ce n'est pas un levier de requête.

### Où part le temps restant (p95 non atteint)

- **Le SQL n'est plus le coût.** Les 8 requêtes font 24 ms en p50 : la liste 10 à 13 ms, les totaux 7 à 8 ms, l'authentification et les noms environ 4 ms. Le reste est du Ruby : la vue (200 lignes, 110 Ko, et le gabarit) prend 19 à 29 ms, la pile Rack et le contrôleur environ 10 ms.
- **Le p95 est la queue, pas le cas courant.** Sur 30 mesures, le p95 est la 2ᵉ plus lente. Chaque exécution en compte 2 ou 3 au-delà de 130 ms. La décomposition par mesure (temps CPU et GC de chaque requête) montre que ces mesures sont du **CPU Ruby sans GC** (237 ms au mur pour 207 ms de CPU, aucun GC), et qu'elles coïncident avec des **compilations YJIT**. YJIT compile une méthode après 30 appels : de la 4ᵉ à la 33ᵉ requête, la page compile de 16 à 78 iseqs par requête (de 97 à 193 ms) ; à la 116ᵉ requête, 328 iseqs, 245 ms. Les 3 chauffes du protocole laissent donc la compilation de YJIT dans les 30 mesures.
- **Une fois la page chaude**, après la 60ᵉ requête (60 mesures) : **p50 54,7 ms, p95 78,0 ms**, dans le budget. Une série de 60 mesures donne aussi 60,0 / 84,3 ms, et une de 90 donne 59,4 / 87,9 ms.
- **Prochains leviers**, hors de ce lot, à jouer un par un :
  1. les totaux par élève plutôt que par devoir : 7 ms. Ils touchent les lignes de #169, et sont donc à jouer après sa fusion ;
  2. le rendu des 200 lignes, sans changer l'écran ;
  3. ou une révision du protocole de l'ADR-0067 (chauffe plus longue que le seuil de YJIT), qui demande la décision du porteur.

---

## Lot 2 — « Travail des élèves » (à jouer)

- **Couche**       : infrastructure
- **Fichiers**     : `app/infrastructure/queries/school/student_work_query.rb` · son test
- **Dépend de**    : Lot 0 ; **après la fusion de #169**, qui modifie `totals_by` et l'index des sessions rendues
- **Test associé** : `test/infrastructure/queries/school/student_work_query_test.rb`
- **Done quand**   : p95 de `/school-admin/classrooms` < 100 ms, contre 229,0 ms (série *après* de ce chantier), mêmes chiffres affichés

## Lot 3 — « Enseignants » : poids du HTML

- **Couche**       : ui (sans changer ce qui est affiché), et une route `GET` de lecture pour le levier 3b
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/school_admin/teachers_controller_test.rb`, `test/system/school_admin/`
- **Done quand**   : HTML de `/school-admin/teachers` < 150 Ko, contre 441,1 Ko. **Non atteint : 152,5 Ko** après les leviers 1 et 3b ; voir « Reste » ci-dessous.

Mesure : base `app_lnclassapp_perf_direction_lot_c` (60 enseignants dans l'établissement mesuré), mode production, `PERF_ONLY=admin_teachers`, protocole de l'ADR-0067 (3 chauffes, 30 × 3, médiane). Une ligne pesait 6,0 Ko après le levier 1 : la modale de confirmation 3,3 Ko (198 Ko pour la page), le menu ⋮ 1,9 Ko (114 Ko), l'indentation environ 0,46 Ko (27 Ko). Sur 103 ms, la vue en prenait environ 72.

### Levier 1 — icônes dessinées une fois (`<symbol>` + `<use>`) ✅ commit `cbf1bddb`

- **Fichiers** : `app/helpers/components_helper.rb` (`ui_icon_sprite`), `app/views/school_admin/teachers/index.html.erb`, `test/helpers/components_helper_test.rb`
- Chaque ligne dessinait cinq heroicons en entier. Ils sont maintenant dessinés une fois pour la page, et chaque ligne les reprend par `<use>`, avec les mêmes attributs racine et la même classe. Les captures sont identiques au pixel près, en clair comme en sombre.

| « Enseignants » | Ko | Ko gzip | p95 |
|---|---|---|---|
| Avant | 441,1 | 17,3 | 149,5 ms |
| Après le levier 1 | **368,5** | 15,2 | 132,1 ms (machine partagée, dans le bruit) |

### Levier 3b — confirmation « Retirer » chargée à la demande ✅ commit `299fac0e`

- **Fichiers** : `config/routes/school_admin.rb` (`GET teachers/:public_id/removal`), `app/controllers/school_admin/teachers_controller.rb` (`#removal`), `app/infrastructure/queries/school/school_teachers_query.rb` (`#teacher`), `app/views/school_admin/teachers/removal.html.erb` (nouvelle), `app/views/school_admin/teachers/index.html.erb`, `app/views/components/_dropdown.html.erb` (indentation seule), `config/locales/school_admin/teachers.fr.yml`, `script/perf/measure_screens.rb` (écrans `admin_teacher_removal` et `admin_teacher_removal_page`)
- La confirmation n'est plus copiée dans chaque ligne. L'entrée « Retirer de l'établissement » du menu ⋮ est un lien `data-turbo-frame="modal"` : la même `<dialog>` arrive par une requête dans le cadre partagé du layout. Sans JavaScript, la même adresse rend une page complète. L'action applique la policy de `DetachTeacher` avant toute lecture. Contrat : [UDR-0056, amendement du 2026-10-04](../../decisions/udr/0056-gestes-de-la-direction.md#amendement-du-2026-10-04--confirmation-du-retrait-chargée-à-la-demande).
- L'indentation des lignes du tableau disparaît : gabarit des lignes sans retrait, puis celui du menu (`components/_dropdown`), qui se répète à chaque ligne. Entre ces éléments, aucun espace ne se voit.

Série appariée « avant » et « après », sur la même machine, à deux minutes d'écart, charge ≈ 1,5 :

| « Enseignants » (30 × 3, médiane) | Ko | Ko gzip | p50 | p95 | Vue p50 | Allocations | Requêtes |
|---|---|---|---|---|---|---|---|
| Avant (levier 1 seul) | 368,5 | 15,2 | 91,7 ms | 118,5 ms | 63,5 ms | 71 731 | 9 |
| Confirmation à la demande + lignes sans retrait (série séparée, plus tôt dans la journée) | 156,0 | 10,1 | 60,2 ms | 94,7 ms | 31,2 ms | 32 046 | 9 |
| **Après** : + menu sans retrait | **152,5** | **10,0** | **62,6 ms** | **121,2 ms** | **30,1 ms** | **32 037** | 9 |

Exécutions *après* : p50 63,7 / 62,6 / 55,8 ms ; p95 121,2 / 108,7 / 160,2 ms. Sur toutes les séries *après* du jour (9 exécutions), la médiane est de 64,5 ms en p50 et de 121,2 ms en p95 ; sur les 6 exécutions *avant*, de 103,5 ms et de 140,2 ms. La vue est divisée par deux et les allocations par 2,2. Le p95, lui, reste dans le bruit de la machine partagée : sa queue vient de la compilation YJIT, comme au lot 1b (§ « Où part le temps restant »).

| Confirmation (nouvelle) | Ko | Ko gzip | p50 | p95 | Requêtes |
|---|---|---|---|---|---|
| Dans le frame `modal` (`admin_teacher_removal`) | **3,6** | 1,4 | 18,4 ms | **30,3 ms** | 5 |
| Page complète, sans JavaScript (`admin_teacher_removal_page`) | 17,2 | 4,3 | 20,8 ms | 41,0 ms | 7 |

**Reste : 2,5 Ko au-delà du budget.** Une ligne pèse maintenant 2,3 Ko, dont 1,75 Ko pour le menu ⋮ ; le haut et le bas de la page (shell, en-tête, `<symbol>`) font 19 Ko. Prochain levier, à jouer seul :
- **3c — attributs racine des icônes portés par le `<symbol>`** : `viewBox`, `fill`, `stroke` et `stroke-width` ne seraient plus répétés sur chaque `<svg><use>`. Trois icônes par ligne, environ 180 octets par ligne. **Estimation : −11 Ko, soit environ 141,5 Ko**, calculée sur le HTML rendu et non mesurée. Le levier touche `ui_icon_sprite` (levier 1) et son test de caractérisation.
- Autre piste, plus large : les cinq écouteurs `@window` de chaque menu fixe (`data-action`, environ 200 octets par ligne). Soixante menus réagissent à chaque défilement. Ce levier touche `dropdown_controller.js`, partagé par toute l'application.

## Lot D — Jeu de mesure (dette, lot à part)

- **Couche**       : mesure
- **Fichiers**     : `script/perf/dataset.rb`
- **Dépend de**    : —
- **Test associé** : `test/performance/school/heavy_screens_budget_test.rb` (`PERF=1`)
- **Done quand**   : le jeu sème des anciens élèves dans l'établissement mesuré (requête du Protocole ci-dessus) et des sessions de remédiation (protocole de `remediation-comptee-faite`), sans transformation manuelle de la copie

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `script/perf/measure_screens.rb` | Lot 0 (même ligne que #169 : fusion sans conflit) |
| `app/infrastructure/queries/school/departed_students_query.rb` | Lot 1b (#169 touche l'en-tête, ligne 4, et `#totals`, lignes 56 à 59 : non touchés ici) |
| `app/infrastructure/queries/school/student_work_query.rb` | Lot 2 (après #169) |
| `script/perf/dataset.rb` | Lot D |

## Portes de sortie

- [x] `memo.md` : métrique nommée, **valeur avant chiffrée**, volume de données précisé, cible chiffrée
- [x] Protocole de mesure écrit et reproductible par quelqu'un d'autre (§ Protocole, requête de transformation comprise)
- [x] Explorer coût rendu : où part réellement le temps (pas une hypothèse) : `EXPLAIN` avant/après, décomposition par mesure
- [x] ADR écrit si un contrat change : **sans objet** (réécriture locale d'une query, aucun index livré, aucun cache)
- [x] Bench versionné, produisant la valeur avant (`script/perf/measure_screens.rb`, `admin_departed_students`)
- [x] Tests de non-régression fonctionnelle verts **avant** le premier levier
- [x] Un lot = un levier = un chiffre
- [x] Chaque levier sans gain mesuré a été **annulé**, pas conservé (Lot 1a)
- [x] Bench après : même machine, même volume, même méthode, ≥ 3 exécutions, médiane
- [x] Tableau `Mesures` complété (Avant / Cible / Après) : memo
- [ ] **Challenger a relancé le bench lui-même** et obtenu le gain annoncé
- [x] Résultat fonctionnel strictement identique (aucun écran, aucune sortie modifiés) : tests de caractérisation, comparaison sur 40 cas
- [x] Pureté domaine · rubocop · tests · brakeman : au vert (voir § Vérifications)
- [x] `journal.md` : leviers abandonnés et pourquoi
- [ ] **Cible p95 < 100 ms** de « Anciens élèves » : non atteinte au protocole (136 ms), atteinte à chaud (78 ms) ; voir « Où part le temps restant »
- [ ] Lot 2 ; Lot 3 : 152,5 Ko, budget de 150 Ko non atteint (levier 3c proposé)

## Vérifications

2026-10-04, sur `perf/ecrans-direction-lents` (code des Lots 0 et 1b) :

- `bin/rails test` : **3 619 runs, 0 échec, 0 erreur**, 8 sauts (tests `PERF=1` et assimilés) ; `coverage/.last_run.json` : **100 % lignes (11 341 / 11 341), 100 % branches (2 886 / 2 886)**.
- `bin/rubocop` : 1 334 fichiers, aucune offense. `bin/brakeman` : aucun avertissement.
- Tests système de la direction (`test/system/school_admin/`) : **14 runs, 0 échec**.
- Fusion d'essai avec `origin/fix/remediation-comptee-faite` (#169) : sans conflit ; tests de `DepartedStudentsQuery` sur le résultat fusionné : 11 runs, 0 échec.
