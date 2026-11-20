# État — partage-classe-k-factor

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-20 · **Vague** : 1 · **Où on en est** : cadrage fait, Lot 0 lancé

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| 0 — socle | executant-lot | `feature/partage-classe-k-factor` | — | — | en cours |
| A — QR | executant-lot | `feature/partage-classe-k-factor-lot-a` | — | — | à lancer |
| B — invitation élève | executant-lot | `feature/partage-classe-k-factor-lot-b` | — | — | à lancer |
| C — attribution | executant-lot | `feature/partage-classe-k-factor-lot-c` | — | — | à lancer |
| D — affiche et kit | executant-lot | `feature/partage-classe-k-factor-lot-d` | — | — | à lancer |
| E — k-factor équipe | executant-lot | `feature/partage-classe-k-factor-lot-e` | — | — | à lancer |

## Décisions

Prises :

- 2026-11-20 · D4 (QR, invitation élève, k-factor, affiche) — par le porteur (programme `retours-terrain-tiassale`)

Ouvertes : `## À trancher` du [journal](journal.md).

## Prochaine action

Lot 0 fusionné → lancer A à E en parallèle → PR prête vers `Develop`.

## Prompt de reprise

```
Orchestrateur de partage-classe-k-factor. Lis docs/chantiers/partage-classe-k-factor/etat.md, vérifie sur GitHub la PR qu'il cite, puis reprends à « Prochaine action ».
```
