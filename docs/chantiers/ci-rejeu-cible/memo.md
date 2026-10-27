# Memo — Rejouer seulement ce qu'un changement peut casser

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-27 |
| **Branche** | `perf/ci-rejeu-cible` |
| **Programme** | — |

---

## Le problème

Le 2026-10-27, une même PR (#316) a joué trois trains locaux (`bin/ci-quiet --full`) : ≈ 50 min. Le deuxième a été relancé pour une ligne de JavaScript, le troisième pour une ligne d'un test de perf. Chacun a rejoué les 6 295 tests Rails et les 6 fichiers de perf, que ces lignes ne pouvaient pas changer : `bin/ci-quiet` ne garde qu'un verdict pour tout l'arbre (ADR-0107).

### Mesure transmise par la session d'orchestration (2026-10-27, machine cloud 4 CPU, `bin/ci-quiet --full` sur `feature/mvp-teacher-student`)

| Étape | Durée |
|---|---|
| Tests système (437 tests, 132 fichiers, `-v`) | 9 min 27 s (≈ 1 043 s cumulés d'après `script/ci/test_timings.yml`) |
| Tests Rails (6 295 runs, couverture 100 %) | 3 min 46 s |
| Import performance (6 fichiers) | 1 min 55 s à 3 min 10 s |
| Brakeman | 22 s |
| Gardes + style + audits + seeds + assets | ≈ 30 s |
| Total `bin/ci` | 15 min 46 s à 18 min 39 s |

## Mesure avant

Machine : session cloud, 4 CPU, PostgreSQL local, Chromium 1243 sans affichage. Volume : la suite entière du dépôt (6 295 tests Rails, 437 tests système dans 132 fichiers, 6 fichiers de perf qui importent 2 000 fiches, 500 lycées…). Trois passages, médiane retenue. N° 1 sur `9ecaa07`, n° 2 et n° 3 sur `16cbd82` (#316 fusionnée pendant le chantier).

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| **S1** — train à froid | `bin/ci-quiet --full`, aucun verdict | **901,6 s** (889,7 · 926,5 · 901,6) | pas de régression ; perf sautée si `PERF_PATHS` n'a pas bougé | protocole P1 |
| **S2** — train rejoué après **une ligne de JavaScript** | après un train vert | **901,6 s** : le verdict par arbre rejoue tout | **≤ 660 s** (11 min) | protocole P2 |
| **S3** — train rejoué après **une ligne d'un test de perf** | après un train vert | **901,6 s** : idem | **≤ 120 s** | protocole P3 |
| Tests de l'inscription (10 fichiers système) | durée cumulée des tests, `-v` | **289,0 s** (289,0 · 285,5 · 304,4) | en baisse | protocole P4 |

Détail par étape (médiane des trois passages) : tests système 528,6 s (526,7 · 561,0 · 528,6), tests Rails 231,7 s (227,1 · 231,7 · 244,2), perf 89,1 s (89,7 · 87,7 · 89,1), Brakeman 18,4 s, le reste < 30 s. La perf a joué aux trois passages alors que rien de `PERF_PATHS` ne différait d'`origin/Develop` aux n° 2 et 3 : `bin/ci` pose `CI=true` (`ActiveSupport::ContinuousIntegration.run`), et la condition `${CI:-}` de l'étape était donc toujours vraie (voir `journal.md`).

Deux passages sont rouges, hors chantier : n° 1, `question_matching_test` (identifiant cherché comme nombre dans la page) et CA-C6 (le bug de minuteur corrigé par #316) ; n° 2, `blog_management_test`. Le n° 3 est vert : c'est la non-régression de départ.

### Protocole (rejouable par le challenger)

Préparer : `source ~/.lnclass-ci-env` ; arbre propre ; machine sans autre suite qui tourne.

- **P1** : `rm -rf tmp/ci-verdicts && time bin/ci-quiet --full`, trois fois ; les durées par étape sont dans `tmp/ci.log` (`passed in` / `failed in`).
- **P2** : après un P1 vert, sur une branche locale jetable, une ligne de commentaire ajoutée à `app/javascript/controllers/classroom/signup_steps_controller.js`, commitée (`SKIP_HOOKS=1`), puis `time bin/ci-quiet --full`. Trois fois, une ligne différente à chaque fois (sinon le verdict de l'essai précédent sert).
- **P3** : idem, une ligne de commentaire dans `test/performance/school/import_schools_performance_test.rb`.
- **P4** : les 10 fichiers système qui remplissent l'inscription (`cold_start`, `pin_reveal`, `teacher_materials`, `student_signup_steps`, `teacher_signup`, `invite_colleague`, `join`, `error_paths`, `boucle_pedagogique`, `public_pages`), `COVERAGE=0 bin/rails test <fichiers> -v`, trois fois ; somme des durées des tests de leurs classes.

Avant ce chantier, P2 et P3 valent P1 par construction : toute ligne de code change l'empreinte de l'arbre, et le train délègue tout à `bin/ci`.

## Pour qui

Les agents et le porteur, à chaque preuve locale d'une PR et à chaque train.

## Pourquoi maintenant

Trois trains pour une PR un jour de pilote : 50 minutes de machine pour deux lignes. Le porteur a validé les six points le 2026-10-27 (« oui, mets en place les 6 points immédiatement »).

## Hors périmètre

- La CI GitHub : elle rejoue tout à la promotion vers `Staging` et reste la preuve d'un train (ADR-0107).
- Accélérer les tests eux-mêmes (requêtes, fabriques) : seules les attentes fixes de l'inscription (point 4).
- Le test instable `test/integration/assessment/question_matching_test.rb` (un identifiant de réponse cherché comme nombre dans toute la page, `\b15\b`, ou égal à une valeur d'ordre `"2"`) : constaté rouge au premier passage de la mesure avant, sur `Develop`. Signalé, pas corrigé ici.

## Les six points validés, et ce qu'ils sont devenus

| Point | Décision | Mesure |
|---|---|---|
| 1. Jamais `--full` vers `Develop` | Livré : `CLAUDE.md`, `docs/workflows/README.md` et `verificateur-ci` le disent ; `executant-lot` ne lançait déjà pas la CI | — |
| 2. Verdict par étape | Livré (ADR-XXXX-verdict-par-etape-de-la-ci), au niveau pr comme au train | S2 |
| 3. Étapes en parallèle en local | **Non livré** | Rails + système + perf ensemble : 779 s et 773 s, contre ≈ 870 s en séquence (−11 %), tout vert. Mais la perf est désormais sautée en local sauf changement de ce qu'elle mesure ; sans elle, Rails + système ensemble : 748 s contre 773 à 793 s en séquence (−3 à −6 %, un passage). Machine saturée (charge 9 pour 4 CPU) : chaque suite ralentit d'autant que l'autre gagne. Le gain ne paie ni les bases séparées dans une même copie ni les journaux entremêlés. |
| 4. Attentes fixes de l'inscription | Livré : 100 ms en test (`config.x.signup_steps_delay_ms`), rien en production (l'attribut n'est pas rendu, le contrôleur garde 1 s). CA-C6 garde 1 s : il prouve un minuteur encore en attente. Les autres `sleep` (0,4 à 0,6 s, transitions CSS) restent : 6 s cumulées en tout, et chacun attend une animation réelle | P4 |
| 5. Découper les fichiers système lents | **Non livré** | Les 6 parts GitHub font déjà 172,8 à 174,2 s (écart 1,4 s, `CI_PLAN.split`) : rien à rééquilibrer. En local, Rails répartit les tests un par un, pas par fichier : découper un fichier ne change rien. `boucle_pedagogique_test` est un seul test (38 à 63 s) : le couper, c'est changer le parcours qu'il prouve. |
| 6. Perf ciblée | Livré : un écart limité à des tests de perf ne joue que ceux-là. Et la perf est enfin sautée en local sans écart (`GITHUB_ACTIONS` au lieu de `CI`) | S3, S1 |

## Questions encore ouvertes

- …
