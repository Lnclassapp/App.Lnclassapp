# Mesure mensuelle

> Chaque règle de sobriété a un chiffre. Le 1er du mois, on le rejoue ; une règle qui ne fait pas bouger son chiffre en deux mois est retirée (memo [`sobriete-tokens`](../chantiers/sobriete-tokens/memo.md)). Origine : proposition 10 du rapport sur la méthode de travail (2026-11-05).

## Ce qu'on mesure

| Mesure | Source | Règle qu'elle juge |
|---|---|---|
| Commits hors fusion par jour, commits par PR, PR de plus de 40 commits | `script/mesure/sobriete` | un commit par lot, 40 commits par session |
| Durée de vie d'une branche, branches de plus d'un jour, fusions de rattrapage | `script/mesure/sobriete` | petits lots, branches de moins d'un jour (`conventions.md` §3) |
| Commits qui touchent l'index des chantiers, commits `docs/` seuls | `script/mesure/sobriete` | index générés, pas de commit `docs/` seul en cours de lot |
| Sessions restées bloquées sur une question | `list_sessions` (état « bloqué ») | contrat de session |
| Coût du plus gros orchestrateur, s'il est lisible | sessions du mois | orchestrateur court |

Le script lit `origin/Develop` ; sans argument, il mesure le mois civil précédent :

```bash
script/mesure/sobriete
script/mesure/sobriete --depuis 2026-10-09 --jusqu-a 2026-11-05
```

## La tâche du 1er du mois

Une tâche programmée part le 1er du mois au matin (heure d'Abidjan). Sa session :

1. lance `script/mesure/sobriete` sur `Develop` à jour ;
2. y ajoute les sessions bloquées du mois et, s'il est lisible, le coût du plus gros orchestrateur ;
3. écrit le tout dans `docs/mesures/AAAA-MM.md`, avec une ligne de lecture par mesure (✅ mieux, ➖ stable, ❌ pire, comparé au mois précédent) ;
4. commite directement sur `Develop` (documentation seule) ;
5. si une règle est ❌ ou ➖ deux mois de suite, ajoute une entrée dans `## À trancher` de `docs/chantiers/sobriete-tokens/journal.md` : garder, changer ou retirer la règle, avec sa recommandation. La boîte de décisions de 12 h la pose au porteur.

Point de départ : [`docs/mesures/2026-10.md`](../mesures/2026-10.md).
