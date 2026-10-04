# Memo — L'audit Yarn bloque toute la CI sur une faille de braces sans correctif

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré en PR |
| **Ouvert le** | 2026-10-03 |
| **Branche** | `fix/audit-yarn-braces` |
| **Programme** | — |

---

## Symptôme

Depuis le 2026-10-03, l'étape « Security: Yarn vulnerability audit » (`yarn npm audit --all --recursive`) échoue sur toutes les branches, `Develop` compris : avis [GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) (identifiant Yarn `1240992`), `braces` ≤ 3.0.3, gravité haute. Aucune PR ne peut être verte.

## Reproduction

`yarn npm audit --all --recursive` sur `Develop` (95257bd5) : code de sortie 1, avis `1240992` sur `braces@3.0.3`.

## Cause

`braces` épuise la pile sur un motif très imbriqué (déni de service). Il n'est tiré que par la chaîne de compilation du CSS (`@tailwindcss/cli` → `@parcel/watcher` et `fast-glob` → `micromatch` → `braces`) : il ne tourne jamais en production et ne lit que les motifs écrits par l'équipe. **3.0.3 est la dernière version publiée** : aucune mise à jour ne corrige.

## Décision du porteur (2026-10-03)

Option 1 : ignorer temporairement cet avis, et lui seul, avec une date de réexamen (**2026-10-17**). L'audit continue de bloquer toute autre faille.

## Correctif

- `.yarnrc.yml` : `npmAuditIgnoreAdvisories: ["1240992"]`, commenté.
- `test/guards/repository_rules_test.rb` : registre `AUDIT_EXCEPTIONS` (avis → date de réexamen). Le garde-fou échoue si un avis est ignoré hors du registre, ou si sa date est dépassée : la dérogation ne peut pas être oubliée.

## Hors périmètre

- Remplacer `@tailwindcss/cli` ou forcer une autre version de `micromatch` : aucune version sûre n'existe à ce jour.
- Toute autre dérogation d'audit.
