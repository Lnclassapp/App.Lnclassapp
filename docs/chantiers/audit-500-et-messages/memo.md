# Memo — Audit : 500 évitables et messages trompeurs

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-08 |
| **Branche** | `fix/audit-500-et-messages` |
| **Source** | `docs/audits/2026-11-08-bugs-code-mort.md` (B-008, B-010, B-014, B-020, B-021, B-022, B-029, B-038, B-039, B-040) |

## Symptôme

- **500 évitables** : une requête forgée (`x=texte` à la place d'un hash) ou une course rare lève une exception de base de données que personne ne traduit.
- **Messages trompeurs** : l'interface annonce un résultat faux (toast « photo retirée » sans photo, « session remplacée » après un double envoi…).

## Reproduction

Un test rouge par constat (voir `journal.md`). Chaque test a été vu échouer avant le correctif.

## Portée

Aucune donnée corrompue à réparer. Corrections locales, sans migration.

## Hors périmètre

Les constats qui demandent une décision produit (quel message, quel droit) ou qui ne se reproduisent pas : listés sous « Reporté » dans la PR et dans `journal.md`.
