# État — retours-terrain-tiassale

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-20 · **Vague** : 1 · **Où on en est** : cadrage fait, trois chantiers lancés en parallèle

## Lots

| Chantier | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| `entree-eleve-unifiee` (D1, D2) | session enfant | — | — | — | en cours |
| `recherche-etablissement` (D3) | session enfant | — | — | — | en cours |
| `partage-classe-k-factor` (D4) | session enfant | — | — | — | en cours |
| Playbook ville (D5) | cette session | `claude/keen-keller-127bnu` | — | — | écrit, à relire par le porteur |

## Décisions

Prises : D1 à D5 du [memo](memo.md), 2026-11-20 — par le porteur.

Ouvertes : sections `## À trancher` des journaux des trois chantiers.

## Prochaine action

Suivre les trois PR ; fusionner `entree-eleve-unifiee` avant `recherche-etablissement` (même formulaire d'inscription élève).

## Prompt de reprise

```
Orchestrateur de retours-terrain-tiassale. Lis docs/chantiers/retours-terrain-tiassale/etat.md, vérifie sur GitHub les PR des trois chantiers, puis fusionne celles qui sont de routine (agent fusionneur), entree-eleve-unifiee avant recherche-etablissement.
```
