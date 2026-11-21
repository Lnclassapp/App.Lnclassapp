# État — demarrage-develop

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-21 · **Vague** : unique · **Où on en est** : lot A en PR, mesure après au déploiement qui suit la fusion

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| A — semis en tâche de fond après `/up` | session_01Q2c4dqm7UqV67RKksosaN2 | `perf/demarrage-develop` | voir la PR | | PR prête |

## Décisions

Ouvertes : `## À trancher` du journal.

## Prochaine action

Après la fusion et le déploiement automatique : `python3 -I script/mesure/demarrage lnclass-develop` (et `lnclass-staging` à son prochain déploiement), 3 déploiements, médiane dans le memo.
