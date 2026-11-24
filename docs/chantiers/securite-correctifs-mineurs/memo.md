# Memo — Correctifs mineurs de la revue de sécurité du passage Staging → main

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-24 |
| **Branche** | `fix/securite-correctifs-mineurs` |
| **Programme** | — |

## Le problème

La revue de sécurité du passage Staging → main (PR #680) a laissé cinq points mineurs : plafond des codes faux différent entre `/login` et `/student`, `.env` du VPS relu sans ignorer commentaires et lignes vides, artefact `ci-tree` accepté sans filtre sur son origine, masquage des journaux sans les jetons GitHub `ghs_` `gho_` `ghu_` `ghr_`, origine joignable sans Cloudflare.

## Décisions

- 2026-11-24, porteur : 5 faux codes au plus par compte, tous points d'entrée confondus (ADR-0050 amendée).
