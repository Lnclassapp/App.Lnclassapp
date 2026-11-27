# État — connexion-numero-d-abord

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-27 · **Vague** : unique · **Où on en est** : **livré en production le 2026-11-27** — train #733 (`Develop` → `Staging`, `4de7dd95`) puis #734 (`Staging` → `main`, `cf8feff9`), suite complète verte, revue de sécurité sans constat, déploiement de production et /up verts. Compris : #728 à #732.

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| A, B, C | session_01Q2c4dn4i37GadzCmkz6EHg | `feature/connexion-numero-d-abord` | #728 | `05514e51` (code) | en production (`cf8feff9`) |
| Train | session_01Q2c4dpYzh5BnuDzdVq5jWt | `Develop` → `Staging` → `main` | #733, #734 | `cf8feff9` (main) | en production |

## Décisions

Prises :

- 2026-11-26 · Pas de code d'établissement à l'inscription enseignant (voie « sans code », ADR-0063) — par le porteur.
- 2026-11-26 · Révéler qu'un numéro a un compte est accepté ; jamais nom, rôle ni classe (ADR-0148) — par le porteur.

Ouvertes : `script/docs/a_trancher`, et `## À trancher` de `journal.md` (5 décisions validées par le porteur le 2026-11-27).

## Prochaine action

Rien sur ce chantier : livré. Dette basse listée dans `journal.md`.

## Prompt de reprise

```
Orchestrateur de connexion-numero-d-abord. Lis docs/chantiers/connexion-numero-d-abord/etat.md, puis : relève les décisions de `## À trancher` du journal auprès du porteur.
```
