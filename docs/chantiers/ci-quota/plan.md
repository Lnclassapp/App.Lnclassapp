# Plan d'exécution — La CI épuise le quota de minutes GitHub Actions

> **Recadré le 2026-10-02** : le runner auto-hébergé est abandonné (lots 0, A, C, D, E de la première version, écrits puis retirés). La CI reste sur GitHub. Méthode : l'algorithme en cinq étapes, dans l'ordre (questionner, supprimer, simplifier, accélérer, automatiser). Décision : [ADR-0069](../../decisions/adr/0069-ci-en-un-job-sur-les-pr-et-promotions-par-preuve.md). Mesure avant : [memo](memo.md#mesure-avant-2026-10-02).
>
> **Cycle optimisation** : un lot = un levier = un chiffre, mesuré avec [`script/ci/billed_minutes`](../../../script/ci/billed_minutes).

## Graphe

```
Lot 1 — Supprimer et simplifier : un job sur les PR prêtes, preuve d'arbre, budgets d'écrans hors CI, Dependabot vers Develop
  ↓
Lot 2 — Rapatrier dans Develop les 8 mises à jour Dependabot fusionnées sur main (PR séparée)
  ↓
Lot 3 — Mesure après : 3 PR de chantier, 3 promotions, 1 PR de documents
  ↓ (si le gain tient et que les runs système restent instables)
Lot 4 — Accélérer : tests système instables sous 2 CPU, puis tests système redescendus au niveau contrôleur (à décider test par test)

Exigence du 2026-10-02 : ≤ 10 min d'horloge par feature
  ↓
Lot 6 — Supprimer : perf d'import hors des runs non tirés, PostgreSQL de l'image (#148, run 472 : 9 min 27, 10 facturées)
  ↓
Lot 7 — Simplifier et accélérer : deux jobs côte à côte, unit et system, encadrés par plan et ci (ADR-0069 §9)
  ↓
Lot 8 — Automatiser : budget de croissance de la suite système, 15 s par chantier, 82 fichiers avec leur durée
  ↓
Chantier selection-par-carte-de-couverture (ouvert le 2026-10-03, hors de ce chantier)
```

---

## Lot 1 — Un job sur les PR prêtes, preuve d'arbre

- **Couche**       : CI
- **Fichiers**     : `.github/workflows/ci.yml` *(`pull_request` seul, brouillons exclus, un job `ci`)*
                     `.github/dependabot.yml` *(`target-branch: Develop`, `groups`)*
                     `config/ci.rb` *(`*_budget_test.rb` hors du groupe `perf`, ADR-0067)*
                     `test/guards/ci_plan_test.rb` *(gardes de l'ADR-0069)*
                     supprimés : `script/ci/runner/*`, `docs/guide/runner-auto-heberge.md`, `test/config/ci_rerun_expired_test.rb`, `.github/workflows/ci-github.yml` ; `config/database.yml` revenu à Develop
- **Dépend de**    : —
- **Test associé** : `test/guards/ci_plan_test.rb` (rouge sur le workflow de Develop : 5 échecs ; vert ensuite), `test/config/ci_tested_tree_test.rb`.
- **Done quand**   : le run de la PR de ce chantier est vert en **un job** et coûte **≤ 15 minutes facturées** (33 avant).

## Lot 2 — Les mises à jour de `main` reviennent dans `Develop`

- **Couche**       : dépendances
- **Fichiers**     : `Gemfile`, `Gemfile.lock` *(rails 8.1.4, json 3.0.2, rqrcode 3.2.0, solid_cable 4.1.0, aws-sdk-s3 1.232.2)* ; les versions d'actions (`checkout@v7`, `cache@v6`, `upload-artifact@v7`) sont déjà dans le workflow du lot 1
- **Dépend de**    : Lot 1 *(le run de cette PR se paie au nouveau tarif)*
- **Test associé** : `bin/ci` complet en local, puis le run de la PR.
- **Done quand**   : `Develop` contient `main` (`git merge-base --is-ancestor origin/main origin/Develop`), suite verte.

## Lot 3 — Mesure après

- **Done quand**   : `script/ci/billed_minutes` sur **3 PR de chantier** (médiane ≤ 15 minutes), **3 promotions** (≤ 1 minute chacune, preuve trouvée), **1 PR de documents** (1 minute) ; colonne *Après* du memo remplie. Chemin d'erreur : une promotion dont l'arbre n'a jamais été testé rejoue la suite.

## Lot 5 — Preuves des sessions cloud (ADR-0069 §8, décidé le 2026-10-02)

- **Couche**       : CI
- **Fichiers**     : `script/ci/prove` *(joue `bin/ci`, publie `arbres/<arbre>` sur `ci/preuves`)*, `test/config/ci_prove_test.rb`
                     `.github/workflows/ci.yml` *(tirage 1 sur 5 fixé par PR, `Staging` toujours rejoué)*, `test/guards/ci_plan_test.rb`
                     **appliqué par le porteur** : `script/ci/tested_tree` *(lit `ci/preuves`)*, `LOCAL_PROOF` dans le workflow, leurs tests
- **Prérequis porteur** : appliquer le patch ; créer le secret `CI_DRAW_SALT` (*Settings → Secrets and variables → Actions*, une valeur aléatoire longue)
- **Done quand**   : une PR prouvée et non tirée coûte ≤ 1 minute ; une PR tirée rejoue la suite ; une promotion vers `Staging` rejoue la suite ; une release vers `main` trouve la preuve GitHub de `Staging`

## Lot 6 — Dix minutes (1) : supprimer (livré, PR #148)

- **Couche**       : CI
- **Fichiers**     : `.github/workflows/ci.yml` *(plus de conteneur de service ; PostgreSQL de l'image ; `CI_GROUP` sans `perf` hors run complet)*, `test/guards/ci_plan_test.rb`
- **Dépend de**    : Lot 5
- **Test associé** : `test/guards/ci_plan_test.rb`
- **Done quand**   : le run de la PR est vert sans conteneur ni perf. **Mesuré** : run 472, `bin/ci` 8 min 52 (8 min 09 au run 407 avec perf et conteneur, sur un runner plus rapide), job 9 min 27, 10 minutes facturées.

## Lot 7 — Dix minutes (2) : deux jobs côte à côte

- **Couche**       : CI
- **Fichiers**     : `.github/workflows/ci.yml` *(jobs `plan`, `unit`, `system`, `ci`)*, `config/ci.rb` *(en-tête)*, `test/guards/ci_plan_test.rb`
- **Dépend de**    : Lot 6
- **Test associé** : `test/guards/ci_plan_test.rb` (quatre jobs, les deux jobs font `bin/ci`, preuve par `ci` seulement, brouillon sans verdict)
- **Done quand**   : le run de la PR de ce lot est vert ; **horloge du job `system` ≤ 10 min**, ≈ 13 minutes facturées pour un run complet, ≈ 2 pour une PR prouvée. Chiffres dans le [journal](journal.md).

## Lot 8 — Automatiser : budget de croissance de la suite système

- **Couche**       : CI
- **Fichiers**     : `script/ci/system_budget.rb`, `test/guards/system_budget_test.rb`, `config/ci.rb` *(étape du groupe `lint`)*, `script/ci/record_timings` *(classes dans un `module`, fichiers disparus élagués)*, `script/ci/test_timings.yml` *(82 fichiers système, run 472)*
- **Dépend de**    : —
- **Test associé** : `test/guards/system_budget_test.rb`
- **Done quand**   : un fichier système sans durée est refusé ; un chantier qui ajoute plus de 15 s de durée enregistrée est refusé ; ce chantier passe (0 s ajoutée).

## Lot 4 — Accélérer (à ouvrir selon le lot 3)

- Les 2 tests système rouges sous 2 CPU (mesure locale du 2026-10-02) et l'échec du run 326 : chantier [`tests-instables`](../tests-instables/memo.md) à rouvrir.
- Les 299 tests système font 57 % du temps d'un run : ceux qui ne vérifient pas un parcours de navigateur (`error_paths`, `design_system`, …) peuvent descendre au niveau contrôleur. **Décision du porteur, test par test.**

---

## Contrat d'exécution (cycle optimisation)

1. **Le bench est versionné** : `script/ci/billed_minutes`.
2. **Non-régression** : mêmes étapes de `bin/ci`, couverture 100 % lignes et branches, aucun test supprimé ni affaibli. Le budget d'écrans n'est pas supprimé : il retourne là où l'ADR-0067 l'avait mis (avant chaque recette).
3. **Un levier par lot**, chiffre noté dans le [journal](journal.md).
4. **Gain nul → le pas est annulé.**

## Portes de sortie

- [ ] Bench versionné, produisant la valeur avant (33 minutes par run complet)
- [ ] Bench après : ≥ 3 runs par nature, médiane
- [ ] Tableau du memo complété (Avant / Après)
- [ ] **Challenger** : déclenche lui-même une PR de chantier et une promotion, relance `billed_minutes`, rejoue le chemin d'erreur (arbre jamais testé → la suite tourne)
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] `journal.md` : leviers abandonnés et pourquoi
