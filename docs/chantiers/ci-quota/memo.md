# Memo — La CI épuise le quota de minutes GitHub Actions

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | cadrage |
| **Ouvert le** | 2026-09-29 |
| **Branche** | `perf/ci-quota` |
| **Programme** | — |

---

## Le problème

Depuis le 2026-09-28 à 10 h 44 UTC, **aucun job de CI ne démarre** : le quota de minutes GitHub Actions de l'organisation est épuisé. Chaque run échoue en quelques secondes, sans étape exécutée, sur toutes les branches. Les PR sont fusionnées sans verdict de la CI.

Le chantier [`ci-rapide`](../ci-rapide/memo.md) (ADR-0064) a fait passer l'horloge d'un run de 9 min 28 à environ 2 min 30 en découpant `bin/ci` en 14 jobs parallèles. Il avait prévenu : chaque job est facturé à la minute entamée et paie son propre démarrage, donc un run consomme environ 2,5 fois plus de minutes ([plan de `ci-rapide`, décisions à soumettre](../ci-rapide/plan.md#décisions-à-soumettre-au-porteur)).

Demande du porteur (2026-09-29) : « ouvre /optimize ci-quota pour amener à moins de 3 minutes ».

## Pour qui

L'équipe et les agents qui ouvrent des PR : sans quota, plus aucune PR n'a de verdict, et le passage `Staging` → `main` se fait à l'aveugle.

## Pourquoi maintenant

La CI est à l'arrêt complet. Tant que la consommation reste la même, la remise à zéro du quota ne fera que repousser la prochaine panne de quelques jours.

## Mesure avant

*En cours de relevé : médiane sur plusieurs runs réussis, horodatages des jobs (API GitHub `list_workflow_jobs`).*

## Hors périmètre

- Le contenu des tests : aucun test n'est supprimé, désactivé ni affaibli ; la couverture reste 100 % lignes et branches sur la suite complète (ADR-0024).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| | | |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
