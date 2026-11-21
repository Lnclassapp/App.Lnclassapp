# État — entree-et-accueil-eleve-allegees

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-21 · **Vague** : retours-terrain-tiassale · **Où on en est** : lots 0, A, B, C, D et corrections des revues sur la branche ; PR prête vers Develop

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| 0, A, B, C, D, R | session_01Q2c4dp38aYFdAEpxJcU5ny | `feature/entree-et-accueil-eleve-allegees` | voir PR | voir PR | PR prête |

## Décisions

Prises :

- 2026-11-21 · Adresse du QR `/ecole/:school_public_id` (identifiant public existant) — par la session du chantier (ADR-0145)
- 2026-11-21 · Fenêtre du premier exercice : une fois par écran chargé, éteinte à la première copie rendue — par l'orchestrateur

Ouvertes : `script/docs/a_trancher`, et les sections `## À trancher` des journaux des chantiers de la vague.

## Prochaine action

Fusion par l'orchestrateur (CI locale verte, tests système compris) ; à la fusion, `script/docs/build_index --number` pour l'ADR et les deux UDR.

## Prompt de reprise

```
Orchestrateur de entree-et-accueil-eleve-allegees. Lis docs/chantiers/entree-et-accueil-eleve-allegees/etat.md, vérifie sur GitHub les PR qu'il cite, puis : vérifie la ligne de preuve sur le SHA de tête et fusionne.
```
