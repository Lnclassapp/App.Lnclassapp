# Journal — Perf des imports à la demande, une CI complète par PR

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-19 | Leviers 2 et 3 retenus, pas la réactivation de la CI GitHub | Choix du porteur : pas de minutes GitHub facturées | Non |
| 2026-10-19 | `script/ci/test_timings.yml` exclu de la comparaison (`PERF_IGNORED`) | Il bouge sur presque chaque PR et ne sert qu'au découpage de GitHub ; sans lui, #237 jouait la perf pour rien | Non |

## Mesure après

| Métrique | Contexte / volume | Avant | Après | Comment mesurée |
|---|---|---|---|---|
| Condition de l'étape perf, #237 | Arbre de `feature/renommage-fiche-revision` (30ba2b44) contre `origin/Develop` du moment (cf7b0730) | joue (1 min 31 s) | saute, 26 ms | commande de l'étape, `bin/rails` remplacé par `echo`, dans un worktree détaché |
| Condition, arbre qui touche `app/infrastructure` | Develop + une ligne dans une requête | joue | joue (23 ms) | idem |
| Condition, `CI=true` | Même arbre que #237 | joue | joue (9 ms) | idem |
| Condition, sans `origin/Develop` | Même arbre que #237, référence inexistante | joue | joue (14 ms) | idem |
| `bin/ci` complet | Conteneur cloud 4 cœurs ; #237 avant (perf jouée), puis #237 au head final (7ace1323, perf jouée contre un Develop qui avait bougé) | 16 min 19 s | 14 min 25 s ; une PR sans les chemins de la perf la saute (≈ 1 min 30 de moins) | `tmp/ci.log` |
| `bin/ci` complets par PR | Une PR de plusieurs lots | 2 | 1 (#266 : une seule CI, sur c9e99813) | Nombre de passages de `bin/ci-quiet` écrits dans la PR avant la fusion |

## Ce qui a dérapé

- **Le premier test de la condition a abîmé le dépôt partagé** (2026-10-19, 21:24). Le pre-commit exporte `GIT_DIR` et `GIT_INDEX_FILE` ; le test, qui joue la condition dans un dépôt jetable (`git init`, `commit`, `update-ref`), a visé le vrai dépôt : `core.bare=true` (le worktree principal ne répondait plus), branche du chantier déplacée sur un commit parasite, index faux. Réparé à la main (`core.bare=false`, `git reset --mixed` sur la base). Le test retire désormais toutes les variables `GIT_*` avant chaque appel à git ; prouvé en le jouant avec `GIT_DIR`, `GIT_INDEX_FILE` et `GIT_WORK_TREE` pointés sur un dépôt leurre, resté intact. Leçon : un test qui lance git doit nettoyer `GIT_*`, il tourne aussi dans un hook.
- `script/ci/test_timings.yml` est dans `script/ci`, donc dans la liste de la fiche, et #237 le modifie (c'est le seul fichier de la liste qu'elle touche). Sans exception, la perf aurait joué sur #237. Le fichier est exclu de la comparaison (`PERF_IGNORED`) : les durées enregistrées ne servent qu'au découpage de GitHub.
- Contre l'`origin/Develop` d'aujourd'hui (#263 a touché le domaine), #237 joue la perf : normal, sa branche n'a pas encore fusionné Develop. La mesure « saute » est prise contre le Develop de son merge-base.

## Ce qu'on a appris sur la codebase

- `git diff --quiet` répond 1 pour un écart et 128 pour une erreur : les deux sont non nuls, le fail-safe tient sans test d'erreur à part.
- La condition vit dans la commande shell de l'étape : le titre et la liste des fichiers ne bougent pas, la garde « les budgets restent hors de `bin/ci` » et le tirage de GitHub restent valides.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-19 |
| **PR** | [#266](https://github.com/Lnclassapp/App.Lnclassapp/pull/266) |
| **ADR produits** | aucun |
| **UDR produits** | aucun |
