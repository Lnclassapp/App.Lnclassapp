# État — entonnoir-aarrr

> Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-16 · **Vague** : unique · **Où on en est** : PR #650 prête vers `Develop`, lots 1 et 2 livrés, revues faites.

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| 1 — StudentFunnelQuery + `entonnoir:brut` | session du chantier | `feature/entonnoir-aarrr` | #650 | voir la ligne de preuve de la PR | PR prête |
| 2 — section de la page Croissance | session du chantier | `feature/entonnoir-aarrr` | #650 | idem | PR prête |

## Décisions

Ouvertes : `journal.md` § À trancher (4 entrées, dont la table d'événements, non réversible).

## Prochaine action

Fusionner #650, puis lancer `bin/rails entonnoir:brut` en production et lire si le décrochage est à l'acquisition ou à l'activation.
