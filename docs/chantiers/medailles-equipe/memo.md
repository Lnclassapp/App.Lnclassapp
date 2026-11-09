# Memo — Médailles : écrans de l'équipe

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-09 |
| **Branche** | `claude/medailles-equipe` |
| **Programme** | — (suite de `medailles-vocabulaire`, voir son `plan.md`) |

---

## Le problème

L'équipe lit encore, au Pilotage (`/teams/dashboard`), une « Réussite moyenne » en pourcentage, et, dans le corrigé d'une fiche de cours, « Question N · X pt ». Le mot « barème » désigne à la fois le plan des classes générées et les seuils de médaille.

## Pour qui

L'équipe Lnclass : Pilotage, corrigé, référentiel (plan des classes), suppression de compte.

## Pourquoi maintenant

Le porteur a tranché le 2026-11-08 (UDR médailles) : la médaille remplace notes, % et moyennes partout où l'équipe les lit ; une répartition, jamais une moyenne.

## Décision

- Pilotage : « Réussite moyenne » devient « Médailles décernées » : Bronze / Argent / Or / Diamant sur la période (`exercise_badges.awarded_at`, une médaille par élève et exercice), « Aucune médaille décernée » sinon. `CACHE_VERSION` 7.
- Corrigé : « Question N » (plus de points) ; « Je m'entraîne (sans médaille) » ; « Cette fiche de cours… ».
- « Barème des classes » → « Plan des classes » (libellés ; routes et domaine inchangés) : « barème » est réservé aux seuils de médaille.
- Suppression de compte : « exercices, médailles et lacunes » (plus de « notes »).

## Hors périmètre

- Chiffres d'usage (connexions, activité, élèves actifs, croissance) : ce ne sont pas des notes.
- Écrans enseignant et direction (`medailles-enseignant`, `medailles-direction`) ; CRM (PR #465).
- Fiche établissement et Pilotage plus légers (E-003, E-004) : voir `journal.md`, dette.
- Les points restent en base et dans les imports JSON.
