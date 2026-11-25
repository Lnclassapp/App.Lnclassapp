# État — demarrage-develop

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-21 · **Vague** : unique · **Où on en est** : lot A fusionné (#673, `0ffd82b`), déployé sur Develop ; retouche #675 fusionnée ; Develop : /up en 16 s au plus puis 5 s ; reste le déploiement de Staging au train

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| A — semis en tâche de fond après `/up` | session_01Q2c4dqm7UqV67RKksosaN2 | `perf/demarrage-develop` | #673 | `aa5571bc` | fusionné |

## Décisions

Ouvertes : `## À trancher` du journal.

## Prochaine action

Dans l'heure qui suit le prochain déploiement de Develop (toute fusion) : `python3 -I script/mesure/demarrage lnclass-develop` (et `lnclass-staging` à son prochain déploiement), 3 déploiements, médiane dans le memo.
