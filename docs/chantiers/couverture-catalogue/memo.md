# Memo — Couverture à 100 % perdue par la refonte des maths

| | |
|---|---|
| **Type de cycle** | bugfix (tests) |
| **Statut** | livré, clos |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `fix/couverture-catalogue` |
| **Programme** | — |

---

## Symptôme

PR de train #370 (`Develop` → `Staging`) : le job `unit unit` est rouge. Tous les tests passent, mais la couverture tombe à 99,88 % des lignes (16781 / 16800) et 98,49 % des branches (4770 / 4843), pour 100 % exigés (ADR-0024). Même résultat en local sur `Develop` (9961fd29). Le train est bloqué.

## Cause

`refonte-contenus-maths` (#362) a été prouvée au niveau pr de `bin/ci-quiet`, qui ne mesure pas la couverture de la suite complète. Ses validations de l'import v3 (`content_node`, `figure`, `statement_blocks`, `notion_sheet`, `import_course_tree`, le port `content_tree_writer_port`) ont des branches de refus qu'aucun test ne joue. Six autres fichiers ont une branche chacun.

## Correctif retenu

Ajouter les tests qui jouent chaque ligne et chaque branche manquante, au plus près du code (test d'entité ou de use case du domaine, sinon de repository / query / contrôleur). Chaque test affirme le comportement (le refus et sa raison, la valeur rendue), pas seulement le passage.

Une branche que rien ne peut atteindre (garde redondante avec une validation en amont, `else` impossible) se retire du code plutôt que d'être couverte par un test artificiel ; chaque retrait est noté au journal avec la raison. Aucun comportement observable ne change. Aucun seuil de couverture ne baisse, aucun `:nocov:` n'est ajouté.

## Portes de sortie

- [x] Suite complète locale : 100 % lignes et branches, 0 échec
- [x] `bin/ci-quiet` vert, ligne de preuve dans la PR
- [x] Statut `ci` vert sur le train #370
