# État — acquisition-classes

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-16 · **Vague** : cadrage · **Où on en est** : phases 1 à 3 faites, en attente de la décision du porteur

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| A — entonnoir des classes | — | — | — | — | à lancer après le train #653 |
| B1 / B2 / B3 | — | — | — | — | conditionnels, après la porte V |

## Décisions

Prises :

- 2026-11-16 · mesurer avant d'agir, un seul lot B — par l'orchestrateur (option prudente, À trancher)

Ouvertes : `script/docs/a_trancher`, et les sections `## À trancher` des journaux des chantiers de la vague.

## Prochaine action

Le porteur décide. Après la fusion du train #653 et de la PR de cadrage : lancer le lot A (`executant-lot`), puis la tâche en production.

## Prompt de reprise

```
Orchestrateur de acquisition-classes. Lis docs/chantiers/acquisition-classes/etat.md, vérifie sur GitHub les PR qu'il cite, puis : lance le lot A du plan si le porteur l'a validé ; sinon, lis la sortie collée au journal et ouvre le lot B désigné.
```
