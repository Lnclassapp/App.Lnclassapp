# Memo — Durées système enregistrées par la CI

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | livré |
| **Ouvert le** | 2026-11-06 |
| **Branche** | `perf/ci-durees-enregistrees` |
| **Programme** | — |

---

## Le problème

Un fichier de test système neuf sans durée dans `script/ci/test_timings.yml` fait échouer la garde `test/guards/system_budget_test.rb` (`missing`) alors que le produit est sain. Il fallait lancer à la main la commande de la garde. Cette commande échouait elle-même : sans `COVERAGE=0`, SimpleCov évaluait les 100 % sur un seul fichier (« SimpleCov failed with exit 2 »).

Origine : proposition 6 du rapport sur la méthode de travail, décision du porteur du 2026-11-06.

## Décision

`bin/ci-quiet` joue lui-même, une fois, les fichiers système sans durée (`-v`, `COVERAGE=0`), passe le journal à `script/ci/record_timings`, modifie `test_timings.yml` dans l'arbre de travail et **s'arrête là** (sortie 1) : « à commiter avec le lot, puis relancer ». Aucune preuve ne vaut pour un arbre non commité ; jouer les autres étapes ferait deux runs complets au lieu d'un. Plus largement, `bin/ci-quiet` n'écrit plus de ligne de preuve quand l'arbre diffère de HEAD (il le dit, sortie 1). La garde de 15 s lit ensuite la durée mesurée : un fichier au-delà du budget reste rouge. Un run rouge n'enregistre rien (ses échecs rapides sous-pèseraient le fichier) et le dit.

## Hors périmètre

Audit des dépendances (tâche programmée), découpage des tâches GitHub (`ci-train-rapide`).

## Mesure avant

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| Verdict et durée de `bin/ci-quiet` | 1 fichier système neuf (1 test, 1 visite), niveau `pr` | ROUGE (garde `missing`), 27 s ; la commande suggérée échoue aussi (coverage) | vert, sans geste manuel, garde budget conservée | `time bin/ci-quiet` |

## Mesure après

| Run | Verdict | Durée |
|---|---|---|
| 1 | vert, durée 1,3 s enregistrée | 36 s |
| 2 | vert | 33 s |
| 3 | vert | 33 s |

Médiane : **vert, 33 s** (mesure du premier état du lot ; depuis l'arrêt après enregistrement, le premier run ne fait que l'enregistrement et le suivant, sur le commit, garde ses verdicts) (les 6 s de plus sont le jeu du fichier, qui servait de toute façon à l'étape système). Même machine, même fichier ; `test_timings.yml` remis à zéro entre les runs.

## Couverture

À vérifier : la couverture à 100 % n'est évaluée que sur la suite complète. Constat : déjà en place pour `bin/ci-quiet` (niveau `pr` : `COVERAGE=0` pour les tests unitaires, les relectures du front et `bin/system-changed` ; niveau `train` : suite complète avec `CI=true`). Le seul cas qui échouait était la commande de rattrapage suggérée par la garde : corrigée (`env COVERAGE=0`, testé).

## Effet de bord noté

`record_timings` retire du fichier les entrées dont le test n'existe plus : le premier enregistrement peut effacer des lignes périmées (3 lignes `test/domain/…` dans la mesure). C'est le comportement existant de l'outil, sans effet sur le budget.
