# Memo — Sobriété de tokens

| | |
|---|---|
| **Type de cycle** | refactoring *(processus, aucun comportement produit)* |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-09 |
| **Branche** | `chore/sobriete-tokens` |
| **Programme** | — |

---

## Le problème

Les sessions de travail consomment beaucoup de tokens. Mesures sur `Develop` (2026-09-24 → 2026-10-09, 16 jours) :

| Mesure | Valeur |
|---|---|
| Commits | 1 319 (901 hors fusions), soit 82 par jour |
| PR fusionnées | 179, soit 5 commits par PR |
| Sessions identifiées (trailer `Claude-Session`) | 28 |
| 3 plus grosses sessions | 365 commits (28 %), dont une de 209 (16 %) |
| Commits `docs` | 317 (24 %) ; 294 ne touchent que `docs/` (33 % hors fusions) |
| Fusions hors PR | 239 sur 418 (57 %) |
| Index `README` ADR / UDR / chantiers | 71 / 70 / 69 modifications (12 / 11 / 11 sur les 3 derniers jours) |
| Corrections / fonctionnalités | 145 / 248 (0,58) ; identity 30, school 26, ui 21 |

À ~1 500 tokens par commit (ajout, message, push, attribution), 901 commits ≈ 1,35 M de tokens (estimation). Le contexte d'une longue session est renvoyé à chaque tour.

Une hypothèse de départ est **réfutée** : `script/ci/test_timings.yml` (45 modifications) n'est pas commité par habitude. La garde `system_budget_test.rb` (ADR-0069 §9) exige une durée pour tout fichier système ajouté. On n'y touche pas.

## Pour qui

Le porteur (coût) et chaque agent (contexte).

## Pourquoi maintenant

La consommation est le premier frein à la cadence. Les règles ci-dessous ne coûtent rien à appliquer.

## Ce qui change

| # | Règle | Cible mesurable |
|---|---|---|
| 1 | Une session par chantier, 40 commits au maximum | plus aucune session au-dessus de 40 commits (3 aujourd'hui) |
| 2 | Un commit par lot, documentation du lot dans le même commit | 5 → 3 commits par PR, soit −360 commits |
| 3 | Les index ADR / UDR / chantiers ne sont modifiés qu'au commit de clôture du chantier | 1 modification par chantier au lieu de ~6 |
| 4 | Pas de fusion depuis l'interface web de GitHub | 0 fusion cassée (4 observées : #48, #49, #50, #52) |
| 5 | `bin/ci` : lire la fin de la sortie et les échecs seulement | −5 000 à −20 000 tokens par exécution (estimation) |

## Hors périmètre

- Générer les index par script (ils portent une colonne « Problématique » rédigée à la main) : chantier séparé si la règle 3 ne suffit pas.
- Réduire le contenu de `docs/guide/` : à décider chantier par chantier, pas ici.
- `test_timings.yml` : hors sujet, voir plus haut.

## Preuve

Même requête dans 30 jours sur `Develop` : commits par PR, taille de la plus grosse session, fusions hors PR. Sans chiffre meilleur, la règle est retirée.
