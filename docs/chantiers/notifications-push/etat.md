# État — notifications-push

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-16 · **Vague** : cadrage (phases 1 à 3) · **Où on en est** : memo, PRD, ADR et UDR proposés, plan écrit ; Web Push seulement

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| 0 | | | | | à lancer |
| A, B, C, D, E, G, H | | | | | à lancer après le Lot 0 |

## Décisions

Prises :

- 2026-11-16 · six motifs, permission après la première réussite, pas de plafond mais des horaires, élèves seulement — par le porteur
- 2026-11-16 · Web Push seulement ; FCM et volet juridique hors de ce chantier — par le porteur (via l'orchestrateur)

Ouvertes : `script/docs/a_trancher` ; `journal.md` § À trancher (aucune bloquante).

## Prochaine action

Après le passage du train et la fusion de la PR de cadrage : poser les décisions ouvertes du plan en un `AskUserQuestion`, puis lancer le Lot 0.

## Prompt de reprise

```
Orchestrateur de notifications-push. Lis docs/chantiers/notifications-push/etat.md, pose les décisions ouvertes de plan.md, puis lance le Lot 0.
```
