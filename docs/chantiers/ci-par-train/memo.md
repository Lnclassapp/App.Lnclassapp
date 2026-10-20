# Memo — Une CI complète par train, plus par PR

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | livré |
| **Ouvert le** | 2026-10-20 |
| **Branche** | `perf/ci-par-train` |
| **Programme** | — |

---

## Le problème

La règle « une CI complète par PR » fait jouer `bin/ci` en entier à chaque fusion, et la CI GitHub est coupée (ADR-0069) : tout tourne sur le poste. Une PR de documentation paie le même prix qu'une migration.

## Pour qui

Le porteur et les agents : chaque suite complète bloque le poste (4 cœurs) et consomme la session.

## Pourquoi maintenant

17 PR fusionnées sur `Develop` le 2026-10-19. Le porteur demande de réduire drastiquement le nombre de suites complètes.

## Mesure avant

Le porteur a demandé d'appliquer les règles sans prendre de relevé complet (2026-10-20). Les chiffres ci-dessous sont des faits relevés, pas un bench.

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| Suites `bin/ci` complètes par PR fusionnée | 28 dernières PR fusionnées sur `Develop` (#237 à #266) | 28 (une par PR) | ≤ 5 | Règle en vigueur ; `git log --first-parent --merges origin/Develop` |
| Suites complètes, journée du 2026-10-19 | 17 PR fusionnées | ≥ 17 | 1 ou 2 (par promotion) | `gh pr list --state merged --base Develop` |
| Durée d'une suite complète | PR #262, poste du porteur | 10 min 17 s | — | Preuve écrite dans la PR #262 |
| Attente de la preuve d'une PR | PR #270 (CI) | suite complète, interrompue après 20 min | ≤ 5 min | `bin/ci-quiet` chronométré |

## Mesure après

| Métrique | Valeur après | Comment mesurée |
|---|---|---|
| Suites complètes pour les 28 mêmes PR | **2** (doc : 1, pr : 25, train : 2) | `CiScope.level` rejoué sur le diff de chaque fusion (`journal.md`) |

## Hors périmètre

- La CI GitHub (coupée, ADR-0069) et la preuve d'arbre publiée (`script/ci/prove`).
- Le contenu de `bin/ci` et de ses groupes.
- Un verdict partagé entre machines : il reste local.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Un hook `pre-push` peut-il garder `Staging` ? | Non : la promotion passe par une PR GitHub, aucun push local vers `Staging` | La garde est la ligne de preuve train exigée dans la PR de promotion |
| Les migrations, fixtures et routes envoient-elles au train ? | Première version oui : 13 PR sur 28 en train | Elles restent au niveau pr et jouent les tests qui les nomment |
| Des tests lisent-ils `docs/` ? | Oui, `docs/contenus/**/*.json` | Seul le Markdown hors du code compte comme doc |

## Questions encore ouvertes

- Partager les verdicts entre machines (branche `ci/preuves`, ADR-0069 §8) si un second poste joue les trains.
