# Memo — La suite unitaire en parts sur GitHub, couverture fusionnée

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-04 |
| **Branche** | `perf/ci-unit-en-parts` |

---

## Le problème

La tâche GitHub `unit unit` joue la suite Rails entière (8 127 tests, seuil 100 % lignes et branches). Elle dure de 3 min 30 à plus de 5 min et a été coupée trois fois le 2026-11-04 par `timeout-minutes: 5` (ADR-0107) : train #468 (run 41907763045, 1re tentative), train #476 (run 41911503446, deux tentatives). Le train #476 n'est bloqué que par elle ; les 22 autres contrôles sont verts.

## Décision du porteur (2026-11-04, non rediscutée)

Deux parts de moins de 3 minutes, plus une tâche qui fusionne leurs couvertures et vérifie 100 % / 100 % sur la suite entière. Aucun test sauté, désactivé ou mis en quarantaine. Plafond de 5 minutes inchangé.

## Mesure avant

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| Durée de la tâche `unit unit` (de `Set up job` à `Complete job`) | Runner `ubuntu-latest`, suite unitaire entière : 862 fichiers, 8 127 tests, couverture lignes + branches | **316 s et 317 s, coupée** (run 41911503446, tentatives 1 et 2) | chaque part < 300 s (plafond), visé < 180 s | `list_workflow_jobs` du run : `completed_at − started_at` par tâche |
| Durée de l'étape `Run bin/ci` de `unit unit` | idem | **253 s et 295 s**, non terminée | — | idem, par étape |
| Couverture de la suite entière | idem | 100 % / 100 % (dernier train vert) | **100 % / 100 %**, inchangée | seuil SimpleCov, sur la fusion des parts |

Protocole après : rejouer la CI GitHub sur l'arbre de la branche (PR de preuve vers `Staging`, tirage `full`), relever les mêmes durées par tâche et par étape, ≥ 3 exécutions (tentatives), médiane ; la tâche `coverage` doit afficher 100 % lignes et branches.

## Hors périmètre

- Accélérer les tests eux-mêmes (fixtures, parallélisme local, `test:prepare`).
- `bin/ci` / `bin/ci-quiet` en local : la suite reste entière, en un passage, seuil compris.
- Les parts `system`, `perf`, `lecons`.
- Les trains #474 et #476, la PR #477.
