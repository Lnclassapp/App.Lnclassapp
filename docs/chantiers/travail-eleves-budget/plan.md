# Plan d'exécution — « Travail des élèves » de la direction sous son budget

> Cycle optimisation : **un lot = un levier = un chiffre**, ordonnés par gain/risque. On s'arrête dès que la cible est atteinte ; un lot devenu inutile se ferme.
> Un seul fichier de code porte le coût (`StudentWorkQuery`) : les leviers se jouent l'un après l'autre, par un seul agent.

## Graphe

```
Lot 0 — bench + non-régression        ✅
  ↓
Lot 1 — agréger par (classe, élève) avant la jointure aux élèves présents   ✅ ea032253
  ↓   (si p95 ≥ 100 ms)
Lot 2 — compter les élèves présents dans la même requête que les totaux     ✅ (gain gardé ; p95 < 100 ms non atteint)
```

## Protocole

- **Base** : `app_lnclassapp_perf_travail`, copie de `app_lnclassapp_perf_remediation` (jeu de l'ADR-0067), migrée au schéma de `Develop` (`d65938c8`) :
  `createdb -T app_lnclassapp_perf_remediation app_lnclassapp_perf_travail`, puis `bin/rails db:migrate` avec son `DATABASE_URL` (`git checkout db/schema.rb` ensuite).
- **Commande** : celle de l'en-tête de `script/perf/measure_screens.rb`, avec `PERF_ONLY=admin_classrooms,admin_classroom`, lancée 3 fois. Protocole de l'ADR-0067 : 3 chauffes, 30 mesures, médiane des 3 exécutions.
- **Série** : chaque levier se mesure **dans la même série** que `Develop` rejoué juste avant (`git stash`, 3 exécutions, `git stash pop`, 3 exécutions). La machine partagée fait varier le témoin de 30 % en p95.
- **Requête** : `EXPLAIN (ANALYZE, BUFFERS)` de la requête des totaux, capturée sur l'établissement mesuré.
- **Non-régression** : `StudentWorkQuery#classrooms` et `#classroom` de **toutes les classes de tous les établissements** du jeu, sérialisés en JSON avant et après le levier : fichiers identiques octet pour octet. Plus les 18 tests de `test/infrastructure/queries/school/student_work_query_test.rb`.

---

## Lot 0 — Bench et non-régression ✅

- **Couche**       : —
- **Fichiers**     : aucun fichier de code ; le bench est `script/perf/measure_screens.rb` (versionné), la non-régression la suite existante
- **Dépend de**    : —
- **Test associé** : `test/infrastructure/queries/school/student_work_query_test.rb` (18 tests, verts sur `Develop`)
- **Done quand**   : la valeur avant est mesurée (memo) ✅ et les tests sont verts avant le premier levier ✅

## Lot 1 — Agréger par (classe, élève) avant la jointure

- **Couche**       : infrastructure
- **Fichiers**     : `app/infrastructure/queries/school/student_work_query.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/school/student_work_query_test.rb`
- **Done quand**   : la requête des totaux passe de 73 ms à < 35 ms (`EXPLAIN ANALYZE`), chiffres identiques sur tout le jeu. ✅ **28–38 ms**, chiffres identiques ; p50 de l'écran 103,6 → 64,7 ms

Le sous-select `handed` rendait une ligne par (classe, devoir, élève) : 22 792 lignes, chacune jointe aux adhésions puis à `users` en boucle imbriquée (l'estimateur prévoyait 1 ligne), puis triées pour `COUNT(DISTINCT élève)`. Il rend maintenant une ligne par (classe, élève) avec `COUNT(DISTINCT devoir)` : 4 235 lignes à joindre, plus de `COUNT(DISTINCT)` au-dessus.

## Lot 2 — Élèves présents comptés dans la requête des totaux

- **Couche**       : infrastructure
- **Fichiers**     : `app/infrastructure/queries/school/student_work_query.rb`
- **Dépend de**    : Lot 1, et seulement si le p95 reste ≥ 100 ms
- **Test associé** : `test/infrastructure/queries/school/student_work_query_test.rb`
- **Done quand**   : une requête de moins pour l'aperçu, p95 de `/school-admin/classrooms` < 100 ms, chiffres identiques sur tout le jeu. **Partiel** : une requête de moins ✅, chiffres identiques ✅, p50 64,6 → 55,9 ms ✅ ; p95 122,1 ms ❌ — la queue vient de la machine ([memo § Mesures](memo.md#mesures-avant--cible--après))

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/infrastructure/queries/school/student_work_query.rb` | Lot 1, puis Lot 2 (séquentiels) |

## Portes de sortie

- [x] `memo.md` : métrique nommée, **valeur avant chiffrée**, volume de données précisé, cible chiffrée
- [x] Protocole de mesure écrit et reproductible par quelqu'un d'autre
- [x] Explorer coût rendu : où part réellement le temps (pas une hypothèse) — [journal](journal.md)
- [x] ADR écrit si un contrat change (callbacks contournés, dénormalisation, cache, port modifié) — aucun contrat ne change
- [x] Bench versionné, produisant la valeur avant
- [x] Tests de non-régression fonctionnelle verts **avant** le premier levier
- [x] Un lot = un levier = un chiffre
- [x] Chaque levier sans gain mesuré a été **annulé**, pas conservé (1a remplacé par 1b ; vue, Arel, cache, dénormalisation écartés)
- [x] Bench après : même machine, même volume, même méthode, ≥ 3 exécutions, médiane
- [x] Tableau `Mesures` complété (Avant / Cible / Après) — p95 < 100 ms **non atteint**, dit tel quel
- [ ] **Challenger a relancé le bench lui-même** et obtenu le gain annoncé
- [x] Résultat fonctionnel strictement identique (aucun écran, aucune sortie modifiés) — 35 035 aperçus et pages, octet pour octet
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [x] `journal.md` : leviers abandonnés et pourquoi — c'est la partie la plus réutilisable

> **Clause de rejet** : le chantier ne se clôt pas sans mesure après, au même volume, par la même méthode, ≥ 3 exécutions, médiane. Le challenger relance lui-même le bench ; un gain qu'il ne retrouve pas n'est pas prouvé.
