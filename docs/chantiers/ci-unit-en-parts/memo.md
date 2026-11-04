# Memo — La suite unitaire en parts sur GitHub, couverture fusionnée

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | livré (PR #478) |
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

## Mesures après

Runner `ubuntu-latest`, même suite (862 fichiers, 8 133 tests à cette date), même méthode (`completed_at − started_at` par tâche). Runs de la PR de preuve #480 (fermée) :

| Tâche | Avant | Run 41916186112 (`53432fe`) | Run 41917971824 (`878c667`) | Cible |
|---|---|---|---|---|
| `unit unit` | 316 s / 317 s, coupée | — | — | — |
| `unit unit:1/2` | — | 193 s (`bin/ci` 170 s) | **214 s** (`bin/ci` 184 s) | < 300 s ✅ · < 180 s ❌ |
| `unit unit:2/2` | — | 191 s (`bin/ci` 159 s) | **206 s** (`bin/ci` 174 s) | < 300 s ✅ · < 180 s ❌ |
| `coverage` | — | 17 s, échec de chargement (corrigé, `7908294`) | **18 s, 100 % / 100 %** (18 700 lignes, 5 763 branches) | 100 % / 100 % ✅ |
| `ci` | rouge | rouge | **vert** | vert ✅ |

- Deux exécutions par part, pas trois : la troisième se lira au prochain train. Médiane provisoire : 204 s (part 1), 199 s (part 2).
- Le plafond de 5 minutes tient avec plus de 85 s de marge ; la visée de 3 minutes n'est pas atteinte (la mise en place, base et assets, pèse 30 à 40 s par part). Une troisième part se décide si une part dépasse 4 min (`UNIT_PARTS`).
- Fidélité de la fusion, en local : les deux parts fusionnées donnent exactement le chiffre de la suite entière (18 701 / 18 701 lignes, 5 765 / 5 767 branches sur `cab6213`, mêmes fichiers en défaut). Parts locales : 140 s et 157 s (4 cœurs), 2 937 + 5 196 = 8 133 tests.
