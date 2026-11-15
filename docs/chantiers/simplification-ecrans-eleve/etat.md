# État — simplification-ecrans-eleve

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-14 · **Vague** : 1 (un seul chantier) · **Où on en est** : lots 0, A, B, C, D commités en local dans une session, une PR vers Develop.

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| 0 règles et socle | cette session | `feature/simplification-ecrans-eleve` | à ouvrir | — | fait (commit local) |
| A accueil | cette session | idem | idem | — | fait (commit local) |
| B matière | cette session | idem | idem | — | fait (commit local) |
| C leçon | cette session | idem | idem | — | fait (commit local) |
| D skill `ecrans-wave` | cette session | idem | idem | — | fait (commit local) |

## Décisions

Prises :

- 2026-11-14 · maquettes validées, jonction à 159 px, icône de leçon automatique, 3 éléments puis « Voir plus (n) » — par le porteur (`maquettes/README.md`).

Ouvertes : `script/docs/a_trancher`, et `## À trancher` du `journal.md`.

## Prochaine action

Fusion de la PR par l'orchestrateur après le vert de la CI et les captures validées ; puis `script/docs/build_index --number` à la fusion (UDR-XXXX).

## Prompt de reprise

```
Orchestrateur de simplification-ecrans-eleve. Lis docs/chantiers/simplification-ecrans-eleve/etat.md, vérifie sur GitHub la PR citée (CI, revues, assigné), puis : fusionne si tout est vert, pose le numéro de l'UDR (script/docs/build_index --number) et mets à jour cet état.
```
