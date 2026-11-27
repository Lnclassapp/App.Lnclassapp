# État — connexion-numero-d-abord

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-27 · **Vague** : unique · **Où on en est** : PR #728 fusionnée dans `Develop` le 2026-11-27 ; ADR-0148 et UDR-0189 numérotées.

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| A, B, C | session_01Q2c4dn4i37GadzCmkz6EHg | `feature/connexion-numero-d-abord` | #728 | `05514e51` (code) | fusionné |

## Décisions

Prises :

- 2026-11-26 · Pas de code d'établissement à l'inscription enseignant (voie « sans code », ADR-0063) — par le porteur.
- 2026-11-26 · Révéler qu'un numéro a un compte est accepté ; jamais nom, rôle ni classe (ADR-0148) — par le porteur.

Ouvertes : `script/docs/a_trancher`, et `## À trancher` de `journal.md` (5 décisions réversibles appliquées par défaut).

## Prochaine action

Rien sur ce chantier ; trancher les 5 entrées de `## À trancher` du journal. Dette basse listée dans `journal.md`.

## Prompt de reprise

```
Orchestrateur de connexion-numero-d-abord. Lis docs/chantiers/connexion-numero-d-abord/etat.md, puis : relève les décisions de `## À trancher` du journal auprès du porteur.
```
