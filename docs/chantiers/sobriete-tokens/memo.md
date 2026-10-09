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
| 4 | Pas de fusion sans preuve : `bin/ci` local écrit dans la PR tant que la CI GitHub est coupée | 0 fusion cassée (4 observées : #48, #49, #50, #52) |
| 5 | `bin/ci` : lire la fin de la sortie et les échecs seulement | −5 000 à −20 000 tokens par exécution (estimation) |

## Ce qui est fait (2026-10-09)

| Reco | Résultat |
|---|---|
| 1, 2, 3 | Règles écrites dans `CLAUDE.md` et `conventions.md` §4 |
| 4 | Réfutée, rien à faire |
| 5 | `bin/ci-quiet` (verdict, échecs, 30 dernières lignes ; journal dans `tmp/ci.log`). Chemin rouge vérifié, chemin vert à vérifier au premier passage complet |
| 6 | Réglage GitHub, à activer par le porteur |
| 7 | Les 56 corrections identity et school sont des causes précises : 6 corrections JPEG successives, 4 « findings de revue » fermés après coup, 2 pertes à la fusion, ~8 défauts d'interface (contraste, titres, espacements). Règle ajoutée : menace écrite avant tout code qui lit un fichier envoyé |
| 2 bis | Graphify : `session-start.sh` l'installe (`uv tool install graphifyy`) et lance `graphify update .` (AST seul, sans modèle) ; échec non bloquant. Le graphe sert déjà aux hooks `hook-guard`. Gain à mesurer : 5 questions de code identiques avec et sans graphe |
| 4 bis | `skillOverrides` dans `.claude/settings.json` : 21 skills `anthropic-skills:*` hors sujet à `off`, 4 skills d'outillage en `name-only` (≈ −3 500 tokens par tour, en cache : estimation sur la taille des descriptions) |
| 5 | Index ADR / UDR générés par `script/docs/build_index` à partir d'un bloc `<!-- index -->` dans chaque fichier (83 ADR, 80 UDR). Les tableaux régénérés sont identiques octet pour octet aux anciens. Le tableau « Décisions remplacées » et l'index des chantiers restent manuels |
| 8 | Les 4 skills de cycle lisent la table de routage et les sections utiles de `conventions.md` (≈ −3 000 à −4 000 tokens par ouverture de chantier) ; seuil de 150 lignes pour les sous-agents |

## Hors périmètre

- Générer le tableau « Décisions remplacées » de l'ADR et l'index des chantiers (structure différente).
- Réduire le contenu de `docs/guide/` : à décider chantier par chantier, pas ici.
- `test_timings.yml` : hors sujet, voir plus haut.

## Preuve

Même requête dans 30 jours sur `Develop` : commits par PR, taille de la plus grosse session, fusions hors PR. Sans chiffre meilleur, la règle est retirée.
