# État — partage-classe-k-factor

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-21 · **Vague** : 1 · **Où on en est** : lots 0, A à E et R fusionnés sur la branche, challenger joué, PR vers `Develop`

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| 0 — socle | executant-lot | `feature/partage-classe-k-factor` | — | — | fusionné |
| A — QR | executant-lot | `feature/partage-classe-k-factor-lot-a` | — | — | fusionné |
| B — invitation élève | executant-lot | `feature/partage-classe-k-factor-lot-b` | — | — | fusionné |
| C — attribution | executant-lot | `feature/partage-classe-k-factor-lot-c` | — | — | fusionné |
| D — affiche et kit | executant-lot | `feature/partage-classe-k-factor-lot-d` | — | — | fusionné |
| E — k-factor équipe | executant-lot | `feature/partage-classe-k-factor-lot-e` | — | — | fusionné |

## Décisions

Prises :

- 2026-11-20 · D4 (QR, invitation élève, k-factor, affiche) — par le porteur (programme `retours-terrain-tiassale`)

Ouvertes : `## À trancher` du [journal](journal.md).

## Prochaine action

PR prête vers `Develop` : surveiller la CI GitHub (tests système), fusionner après `entree-eleve-unifiee` (rebase si le formulaire d'inscription entre en conflit).

## Prompt de reprise

```
Orchestrateur de partage-classe-k-factor. Lis docs/chantiers/partage-classe-k-factor/etat.md, vérifie sur GitHub la PR qu'il cite, puis reprends à « Prochaine action ».
```
