# Plan d'exécution — Écrans lourds : index et requêtes avant tout cache

> Décisions du porteur du 2026-09-29 : budgets gravés dans l'[ADR-0067](../../decisions/adr/0067-budgets-de-temps-serveur-des-ecrans.md) ; pistes 1 à 4 du [memo](memo.md) dans ce chantier, **SQL et index seulement, aucune vue modifiée** (des lots UX parallèles touchent les vues) ; piste 5 après ces lots UX.
> Format des lots : [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Cycle : [optimisation](../../workflows/optimisation.md) — **un lot = un levier = un chiffre**.

## Graphe

```
Lot 0 — Bench et budgets (fait en cadrage : script/perf/, mesure « avant »)
  ↓
  ├─► Lot 1 — Travail des élèves : index partiel + totals_by        ┐
  ├─► Lot 2a — Pilotage : index de période (ADR-0062)                ├─ séquentiels ici (un seul agent,
  │     ↓                                                            │  une seule base de mesure) ;
  │   Lot 2b — Pilotage : placements lus une fois                    │  indépendants par les fichiers
  │     ↓                                                            │
  │   Lot 2c — Pilotage « année » : cache 5 min (porteur)            │
  └─► Lot 3 — Recherche : pg_trgm + index trigrammes                 ┘
  ↓
Lot 4 — Budgets : ADR-0067, test PERF=1, amendement ADR-0062, mesure « après »
  ⋯
Lot 5 — Listes légères (piste 5) : APRÈS les lots UX qui touchent teams/schools et catalog/courses
```

Contrat d'exécution de chaque lot (cycle optimisation, étape 4) :

1. le bench reproductible existe et produit la valeur *avant* (`script/perf/measure_screens.rb`, `PERF_ONLY=…`) ;
2. un test de non-régression des définitions est **vert avant** le levier (cas limites) ;
3. **un seul levier**, puis le bench relancé (3 exécutions, médiane), chiffre noté dans le memo ;
4. gain nul ou marginal → le pas est annulé, et le journal dit pourquoi.

**Le chantier ne se clôt pas sans mesure après** : même machine, même jeu, même méthode, 3 exécutions, médiane. Sans chiffre après, pas de PR.

---

## Lot 1 — Travail des élèves

- **Couche**       : infrastructure
- **Fichiers**     : `db/migrate/20260929200000_add_handed_in_index_to_exercise_sessions.rb`
                     `app/infrastructure/queries/school/student_work_query.rb`
                     `test/infrastructure/queries/school/student_work_query_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `student_work_query_test.rb` (nouveau cas : un élève dans deux classes, présent dans l'une, parti de l'autre)
- **Done quand**   : p95 de `/school-admin/classrooms` (lycée de 4 235 élèves) **< 100 ms**, contre 240 ms avant, mêmes chiffres affichés

## Lot 2a — Pilotage : index de période

- **Couche**       : infrastructure (migration seule)
- **Fichiers**     : `db/migrate/20260929200100_add_period_indexes_for_team_dashboard.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `team_dashboard_query_test.rb` (inchangé, vert)
- **Done quand**   : p50 du pilotage 7 j passe de 338 ms à ~250 ms, mesuré au même volume

## Lot 2b — Pilotage : une lecture des élèves placés

- **Couche**       : infrastructure
- **Fichiers**     : `app/infrastructure/queries/school/team_dashboard_query.rb`
                     `test/infrastructure/queries/school/team_dashboard_query_test.rb`
- **Dépend de**    : Lot 2a (même écran : mesurer après 2a pour isoler le gain de 2b)
- **Test associé** : `team_dashboard_query_test.rb` (nouveau cas limite des placements ; nombre de requêtes 16 / 18)
- **Done quand**   : p95 du pilotage **< 300 ms** sur 7 jours **et** sur l'année, mesuré au même volume

## Lot 2c — Pilotage « année » : chiffres gardés 5 minutes (décision du porteur, après la mesure de 2b)

- **Couche**       : infrastructure
- **Fichiers**     : `app/infrastructure/queries/school/team_dashboard_query.rb` · `test/infrastructure/queries/school/team_dashboard_query_test.rb`
                     `script/perf/measure_screens.rb` (`PERF_COLD=1`) · `test/performance/school/heavy_screens_budget_test.rb`
                     `docs/decisions/adr/0062-…` *(second amendement)*
- **Dépend de**    : Lot 2b (le cache ne se pose qu'après les index et la réécriture, ADR-0062)
- **Test associé** : `team_dashboard_query_test.rb` (mêmes chiffres avec et sans cache ; pas de SQL de chiffres dans les 5 min ; expiré après 5 min ; deux filtres, deux entrées ; 7 et 30 jours en direct)
- **Done quand**   : p95 de la vue « année » **< 300 ms à chaud**, froid mesuré et noté ; `PERF=1` vert

## Lot 3 — Recherche : `pg_trgm`

- **Couche**       : infrastructure (migration) + test
- **Fichiers**     : `db/migrate/20260929200200_add_trigram_search_indexes.rb`
                     `test/infrastructure/queries/trigram_search_indexes_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `account_search_query_test.rb`, `schools_query_test.rb` (inchangés) ; `trigram_search_indexes_test.rb` (le planificateur sait utiliser chaque index d'expression)
- **Done quand**   : p95 de la recherche du pilotage « kou » **< 100 ms**, contre 293 ms ; aucune recherche de 2 caractères plus lente

## Lot 4 — Budgets et preuve

- **Couche**       : docs + test de performance
- **Fichiers**     : `docs/decisions/adr/0067-budgets-de-temps-serveur-des-ecrans.md`
                     `docs/decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md` *(amendement)*
                     `docs/decisions/adr/README.md`
                     `script/perf/dataset.rb` · `script/perf/seed_dataset.rb`
                     `test/performance/school/heavy_screens_budget_test.rb`
                     `docs/chantiers/cache-ecrans-lourds/{memo,journal,plan}.md`
- **Dépend de**    : Lots 1, 2b, 3
- **Test associé** : `PERF=1 PARALLEL_WORKERS=1 bin/rails test test/performance/school/heavy_screens_budget_test.rb`
- **Done quand**   : le tableau « Mesure après » du memo est rempli pour les 28 écrans, et les budgets tenus ou non sont dits

## Lot 5 — Listes légères (piste 5) — **repris le 2026-10-05 par `politique-cache`, lots E3 et E4**

> Décision du porteur, 2026-10-05. La modale partagée des établissements devient la confirmation lue à la demande (E3, DRENA comprises). Le cache des cartes du catalogue est remplacé par une pagination chargée au défilement (E4), qui allège aussi la page. Catalogue et DRENA tiennent leur budget ; les établissements tiennent le temps et pèsent encore 222 Ko ([memo de `politique-cache`](../politique-cache/memo.md#lots-e3-et-e4--les-listes-encore-lourdes-2026-10-05)).

- **Couche**       : ui (vues) — **c'est pour cela qu'il attend**
- **Fichiers**     : `app/views/teams/schools/_school_row.html.erb` (une modale de confirmation partagée au lieu de deux par ligne) ; `app/views/catalog/courses/_course_card.html.erb` et `index` (`render collection, cached: true`)
- **Dépend de**    : **la fin des lots UX (`finitions-ux`) qui touchent ces vues** ; un ADR pour le cache de fragment (clé, invalidation, ADR-0028, ADR-0054)
- **Test associé** : tests système des établissements et du catalogue, strictement inchangés à l'écran
- **Done quand**   : `/teams/schools` et `/courses` sous **150 Ko** de HTML brut et **< 25 ms** de vue p50, écran identique

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `db/schema.rb` | Lots 1, 2a, 3 (séquentiels ; seules les lignes réelles de chaque migration, le dump local réécrit les CHECK `ANY (ARRAY…)`) |
| `app/infrastructure/queries/school/student_work_query.rb` | Lot 1 |
| `app/infrastructure/queries/school/team_dashboard_query.rb` | Lot 2b |
| `docs/decisions/adr/0062-…` | Lot 4 |
| vues `teams/schools`, `catalog/courses` | Lot 5 — **pas dans ce chantier** |

## Portes de sortie

- [x] `memo.md` : métrique nommée, **valeur avant chiffrée**, volume de données précisé, cible chiffrée
- [x] Protocole de mesure écrit et reproductible par quelqu'un d'autre
- [x] Explorer coût rendu : où part réellement le temps (pas une hypothèse)
- [x] ADR écrit si un contrat change (ADR-0067 budgets ; amendements ADR-0062 : index, `pg_trgm`, lecture groupée ; cache 5 min de la vue « année »)
- [x] Bench versionné, produisant la valeur avant
- [x] Tests de non-régression fonctionnelle verts **avant** le premier levier
- [x] Un lot = un levier = un chiffre
- [x] Chaque levier sans gain mesuré a été **annulé**, pas conservé (voir journal)
- [x] Bench après : même machine, même volume, même méthode, ≥ 3 exécutions, médiane
- [x] Tableau `Mesures` complété (Avant / Cible / Après)
- [ ] **Challenger a relancé le bench lui-même** et obtenu le gain annoncé
- [x] Résultat fonctionnel strictement identique (aucun écran, aucune sortie modifiés)
- [x] Pureté domaine · rubocop · tests · brakeman : au vert
- [x] `journal.md` : leviers abandonnés et pourquoi
