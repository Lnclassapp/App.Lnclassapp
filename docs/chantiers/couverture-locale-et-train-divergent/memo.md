# Memo — Couverture locale et train divergents

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en revue |
| **Ouvert le** | 2026-11-15 |
| **Branche** | `fix/couverture-locale-et-train-divergent` |
| **Programme** | — |

---

## Le problème

Sur le même arbre (`origin/Develop` à `c4a67a91`), le niveau local (`env DEFAULT_TEST_EXCLUDE=… bin/rails test`, `config/ci.rb`) mesurait 99,46 % des lignes et 99,26 % des branches, quand le job `coverage` du train, lui, passait à 100 %. Le fichier en cause : `lib/contenus/corrections_production.rb`, 0/118 lignes, 0/51 branches, alors que son test (12 tests) passe.

## Verdict

**Le contrôle fautif est la mesure locale. Le train a raison : le script est testé en CI.**

Mesuré sur le même arbre, les mêmes 983 fichiers de test, les mêmes 9 369 identifiants de test (9 381 runs des deux côtés) :

| Chemin | Runs | Couverture | `corrections_production.rb` dans le `.resultset.json` |
|---|---|---|---|
| Découverte par défaut (`bin/rails test`, niveau local) | 9381 | 99,46 % / 99,26 % | **absent** des 5 processus |
| Liste explicite de fichiers (comme chaque part du train) | 9381 | 100 % / 100 % | présent dans les 5 processus |

## La cause

`bin/rails test` **sans fichier** passe par `test:prepare`, qui charge toutes les tâches rake. `lib/tasks/contenus_corriger.rake` faisait `require Rails.root.join("lib/contenus/corrections_production")` **en tête de fichier** : le script était donc chargé avant que `test_helper` démarre SimpleCov. Hors de `Coverage`, aucune ligne n'est suivie (pas même celles de définition du module) ; le `require` du test devenait un no-op ; `cover "{app,lib}/**/*.rb"` comptait le fichier à 0 %. Avec des fichiers nommés (les parts du train), `test:prepare` est sauté, les tâches ne sont pas chargées, et le fichier est requis après le démarrage de la mesure.

Preuves : `bin/rails runner 'Rails.application.load_tasks'` fait passer le fichier de 0 à 1 dans `$LOADED_FEATURES` ; un `bin/rails test` sans argument restreint à `test/tasks` le sort de la mesure (42 tests, fichier absent) ; le même fichier de test joué seul, ou avec n'importe quel autre dossier de test nommé, le mesure.

L'hypothèse d'un fichier « compté couvert sans l'être » par le train est écartée : dans le train, il est mesuré (présent dans le résultat de chaque processus) et ses 118 lignes et 51 branches sont jouées.

## Correctif

- `lib/tasks/contenus_corriger.rake` : le `require` passe dans le corps de la tâche (comme `apercu.rake` et `pages_lentes.rake`).
- `test/guards/repository_rules_test.rb` : une règle refuse tout `require`/`load` de code du dépôt en tête d'un `.rake` (rouge sans le correctif, vert avec).
- Après correctif, la commande locale de `config/ci.rb` donne 9381 runs, 79 655 assertions, 0 échec, **100 % lignes (22181/22181) et 100 % branches (6917/6917)**, exit 0, en 5 min 10 s en entier (aucun temps ajouté : une règle de garde de quelques ms, `ci.yml` intact).

## Autres fichiers dans le même cas

Aucun. Un fichier suivi mais jamais chargé n'existe ni côté train (100 % : tout `app/` et `lib/` est mesuré et joué), ni côté local après correctif. Seul fichier `.rake` avec un `require` de code en tête : `contenus_corriger.rake`. Les autres (`apercu.rake`, `pages_lentes.rake`) requièrent dans la tâche. `test/tasks/` : 3 fichiers, tous joués des deux côtés. Les ensembles de fichiers de test sont identiques (`CiPlan.files` contre glob par défaut : 983 / 983, différence vide).

## Hors périmètre

- Aucun test ajouté, aucun seuil touché, aucun filtre ni exclusion, `ci.yml` intact.
- Le niveau local reste « le seuil sur toute la suite, en un run » ; on ne change pas de commande.

## Articulation avec la PR #637 (`couverture-branches-visible`)

Complémentaires, sans conflit de fichier (#637 : `bin/ci-quiet`, `script/ci/coverage_touched*`, ADR ; ici : `lib/tasks`, `test/guards`). #637 joue des fichiers de test **nommés** au niveau `pr` : `test:prepare` y est sauté, donc elle n'avait pas ce défaut. Mais le même piège aurait faussé son rapport dès qu'un fichier touché de `lib/` est chargé par une tâche rake. L'une ne rend pas l'autre inutile.
