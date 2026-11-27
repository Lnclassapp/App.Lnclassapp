# État — connexion-numero-d-abord

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-26 · **Vague** : unique · **Où on en est** : PR #728 vers `Develop` prête, `bin/ci-quiet` vert, revues faites ; en attente de fusion.

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| A, B, C | session_01Q2c4dn4i37GadzCmkz6EHg | `feature/connexion-numero-d-abord` | #728 | `05514e51` (code) | PR prête |

## Décisions

Prises :

- 2026-11-26 · Pas de code d'établissement à l'inscription enseignant (voie « sans code », ADR-0063) — par le porteur.
- 2026-11-26 · Révéler qu'un numéro a un compte est accepté ; jamais nom, rôle ni classe (ADR-XXXX-connexion-revele-un-numero-inscrit) — par le porteur.

Ouvertes : `script/docs/a_trancher`, et `## À trancher` de `journal.md` (5 décisions réversibles appliquées par défaut).

## Prochaine action

Fusionner #728 vers `Develop` (`fusionneur`) ; au commit de clôture, numéroter l'ADR et l'UDR (`script/docs/build_index --number`). Dette basse listée dans `journal.md`.

## Prompt de reprise

```
Orchestrateur de connexion-numero-d-abord. Lis docs/chantiers/connexion-numero-d-abord/etat.md, vérifie sur GitHub la PR #728, puis : fusionne-la si elle est verte et sans revue bloquante, sinon traite les retours.
```
