# Memo — Le test « une restauration validée la première sort le compte de la purge » échoue parfois

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | preuve |
| **Ouvert le** | 2026-11-15 |
| **Branche** | `fix/test-restauration-purge-instable` |
| **Programme** | — |

---

## Symptôme

Train #631 (run 43663286358, `c4a67a9`), tâche `unit 1/3` : `StaffRestoreConcurrencyTest#test_a_restoration_that_commits_first_takes_the_account_out_of_the_30-day_purge` (l. 81) — `Expected: 0, Actual: 1`. Relancé : vert. Le diff du train ne touche ni restauration ni purge.

## Verdict : c'est le test, pas le code

Le test envoyait son signal (`restoring << true`) **avant** que `restore` ait pris le verrou de l'établissement. La purge, lancée aussitôt par le fil principal, pouvait prendre le verrou la première : elle supprimait alors un compte encore archivé, ce qui est légitime (elle gagne la course, `claim_for_purge` relit la ligne sous le verrou). Le test supposait un ordre qu'il ne garantissait pas ; le `sleep 0.3` ne faisait que tenir la transaction ouverte.

Le code est sain : `restore` et `claim_for_purge` se sérialisent sur la ligne de l'établissement et relisent sous le verrou.

## Reproduction (mesurée)

Test rejoué dans un même process (méthode seule, sans autre test) :

| Condition | Échecs |
|---|---|
| Machine au repos | 0 / 100 |
| 8 boucles CPU en parallèle (4 cœurs) | **10 / 100**, même message `Expected: 0 / Actual: 1` |

## Correction

Le test impose l'ordre au lieu de l'espérer : (1) la restauration appelle `restore` dans une transaction qu'elle garde ouverte (le verrou tient) et le signale **ensuite** ; (2) la purge démarre ; (3) le test attend, en interrogeant `pg_stat_activity`, qu'une connexion soit **réellement bloquée sur un verrou** ; (4) seulement alors la restauration valide. Plus de `sleep`. Attente bornée à 10 s, échec explicite sinon. Requête hors cache (`uncached`) : le cache de requêtes renvoyait toujours la première réponse.

La garantie est intacte, et plus forte : la purge est prouvée bloquée derrière la restauration, puis relit une ligne restaurée (0 supprimé, `archived_at` nul). Mutation vérifiée : sans le verrou dans `claim_for_purge`, le test échoue.

## Preuve

Même charge (8 boucles CPU), 100 passages : **0 échec / 100** (avant : 10 / 100). Au repos : 0 / 100.
